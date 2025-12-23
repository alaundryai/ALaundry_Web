import 'package:ailaundry_web/models/washer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WasherService {
  final SupabaseClient client;

  WasherService(this.client);

  Future<List<Washer>> fetchWashers({String? role}) async {
    var query = client.from('laundry_users').select();
    
    if (role != null) {
      query = query.eq('role', role);
    }
    
    final response = await query.order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Washer.fromMap(e))
        .toList();
  }

  Future<List<Washer>> fetchAllUsers() async {
    final response = await client
        .from('laundry_users')
        .select()
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((e) => Washer.fromMap(e))
        .toList();
  }

  /// Create a washer by directly inserting into laundry_users (legacy method)
  /// Note: This doesn't create an auth user. Use createWasherWithAuth instead.
  Future<Washer> createWasher(Washer washer) async {
    final response = await client
        .from('laundry_users')
        .insert(washer.toMap(includeIsActive: false))
        .select()
        .single();

    return Washer.fromMap(response);
  }

  /// Create a user with Supabase Auth and send invitation email
  /// This method:
  /// 1. Calls the invite-user Edge Function (uses service role key server-side)
  /// 2. Edge Function creates auth user via inviteUserByEmail
  /// 3. Sends invitation email automatically
  /// 4. SQL trigger automatically creates laundry_users record
  /// 
  /// Returns the created Washer object
  Future<Washer> createWasherWithAuth({
    required String name,
    required String email,
    required String role,
    String? redirectTo,
  }) async {
    try {
      // Call the Edge Function to invite user
      // The Edge Function uses service role key and handles admin privileges
      final response = await client.functions.invoke(
        'invite-user',
        body: {
          'name': name,
          'email': email,
          'role': role,
          if (redirectTo != null) 'redirectTo': redirectTo,
        },
      );

      if (response.status != 200) {
        final errorData = response.data;
        final errorMessage = errorData is Map
            ? (errorData['error'] as String? ?? 'Failed to create user')
            : 'Failed to create user';
        throw Exception(errorMessage);
      }

      final responseData = response.data as Map<String, dynamic>;
      final userData = responseData['user'] as Map<String, dynamic>?;

      if (userData == null) {
        throw Exception('Failed to create user: No user data returned');
      }

      return Washer.fromMap(userData);
    } catch (e) {
      throw Exception('Failed to create user with auth: $e');
    }
  }

  Future<Washer> updateWasher(String id, Map<String, dynamic> updates) async {
    try {
      // Try using RPC function first (bypasses RLS), then fall back to direct update
      try {
        // Convert updates map to JSONB format for the RPC function
        // Filter out columns that don't exist in laundry_users table
        final updatesJson = <String, dynamic>{};
        final allowedColumns = {'name', 'email', 'role', 'is_active'};
        updates.forEach((key, value) {
          if (value != null && allowedColumns.contains(key)) {
            updatesJson[key] = value;
          }
        });
        
        // Try calling the database function first (if it exists)
        // Note: Supabase RPC expects parameters to match the function signature exactly
        final response = await client.rpc(
          'update_laundry_user',
          params: {
            'p_user_id': id,
            'p_updates': updatesJson, // JSONB parameter
          },
        );
        
        // Handle different response types
        if (response != null) {
          if (response is Map) {
            return Washer.fromMap(response as Map<String, dynamic>);
          } else if (response is List && response.isNotEmpty) {
            return Washer.fromMap(response[0] as Map<String, dynamic>);
          }
        }
        
        // If RPC returns null or unexpected format, try to fetch the updated user
        final updatedUser = await client
            .from('laundry_users')
            .select()
            .eq('id', id)
            .maybeSingle();
        
        if (updatedUser != null) {
          return Washer.fromMap(updatedUser);
        } else {
          throw Exception('RPC function executed but user not found after update');
        }
      } catch (rpcError) {
        final errorString = rpcError.toString().toLowerCase();
        
        // Log the full error for debugging
        print('RPC call error: $rpcError');
        print('Error string: $errorString');
        
        // Function might not exist, try direct update
        if (errorString.contains('function') || 
            errorString.contains('does not exist') ||
            errorString.contains('42883') ||
            errorString.contains('not found')) {
          // Function doesn't exist, try direct update
          print('RPC function update_laundry_user not found, trying direct update');
        } else {
          // Other RPC error - might be permission, parameter mismatch, or other issue
          print('RPC error (might be parameter mismatch or permission): $rpcError');
          // Re-throw to show the actual error to the user
          throw Exception('RPC function error: $rpcError. Please check: 1) Function exists in public schema, 2) Function signature matches (UUID, JSONB), 3) You have execute permission.');
        }
      }
      
      // Fallback to direct update
      // First check if user exists
      final userCheck = await client
          .from('laundry_users')
          .select('id')
          .eq('id', id)
          .maybeSingle();
      
      if (userCheck == null) {
        throw Exception('User not found. The user may have been deleted.');
      }
      
      // Perform the update
      final response = await client
          .from('laundry_users')
          .update(updates)
          .eq('id', id)
          .select()
          .maybeSingle();

      if (response == null) {
        throw Exception('Update failed. No rows were updated. This is likely due to Row Level Security (RLS) policies. Please run the SQL in create_update_functions.sql in your Supabase SQL Editor to create the update_laundry_user function that bypasses RLS.');
      }

      return Washer.fromMap(response);
    } catch (e) {
      // Handle permission/RLS errors
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission') || 
          errorString.contains('rls') ||
          errorString.contains('pgrst301') ||
          errorString.contains('pgrst116')) {
        throw Exception('Permission denied. Please run the SQL in create_update_functions.sql in your Supabase SQL Editor to create the update_laundry_user RPC function that bypasses RLS.');
      }
      rethrow;
    }
  }

  Future<void> deleteWasher(String id) async {
    await client.from('laundry_users').delete().eq('id', id);
  }

  Future<void> toggleUserStatus(String id, bool isActive) async {
    try {
      // Try using RPC function first (bypasses RLS), then fall back to direct update
      try {
        // Try calling the database function first (if it exists)
        await client.rpc('update_user_status', params: {
          'p_user_id': id,
          'p_is_active': isActive,
        });
        
        // If RPC succeeds, verify the update
        final verifyResponse = await client
            .from('laundry_users')
            .select('is_active')
            .eq('id', id)
            .maybeSingle();
        
        if (verifyResponse != null) {
          // Verify the update worked (handle both boolean and integer types)
          final updatedValue = verifyResponse['is_active'];
          final bool expectedBool = isActive;
          final bool actualBool = updatedValue is bool 
              ? updatedValue 
              : (updatedValue == 1 || updatedValue == true || updatedValue == 'true');
          
          if (actualBool != expectedBool) {
            print('Warning: Status update verification mismatch. Expected: $expectedBool, Got: $actualBool');
          }
          return; // Success
        }
      } catch (rpcError) {
        // Function might not exist, try direct update
        if (rpcError.toString().contains('function') || 
            rpcError.toString().contains('does not exist')) {
          // Function doesn't exist, try direct update
          // This will work if RLS allows it
        } else {
          // Other RPC error, rethrow
          throw rpcError;
        }
      }
      
      // Fallback to direct update
      // Update the status and get the updated record
      final updateResponse = await client
          .from('laundry_users')
          .update({'is_active': isActive})
          .eq('id', id)
          .select('is_active')
          .maybeSingle();
      
      // Check if update was successful
      if (updateResponse == null) {
        // Try to verify if user exists
        final userCheck = await client
            .from('laundry_users')
            .select('id')
            .eq('id', id)
            .maybeSingle();
        
        if (userCheck == null) {
          throw Exception('User not found. The user may have been deleted.');
        } else {
          throw Exception('Update failed. You may not have permission to update this user, or the is_active column may not exist. Please create an update_user_status RPC function in your database to bypass RLS.');
        }
      }
      
      // Verify the update worked (handle both boolean and integer types)
      final updatedValue = updateResponse['is_active'];
      final bool expectedBool = isActive;
      final bool actualBool = updatedValue is bool 
          ? updatedValue 
          : (updatedValue == 1 || updatedValue == true || updatedValue == 'true');
      
      if (actualBool != expectedBool) {
        // Log warning but don't throw - the update might have succeeded but verification failed
        // This could happen due to database triggers or type conversions
        print('Warning: Status update verification mismatch. Expected: $expectedBool, Got: $actualBool');
      }
    } catch (e) {
      // If is_active column doesn't exist, throw a helpful error
      if (e.toString().contains('is_active') || 
          e.toString().contains('PGRST204') ||
          (e.toString().contains('column') && e.toString().contains('does not exist'))) {
        throw Exception('The is_active column does not exist in the database. Please run the migration to add it.');
      }
      // If it's a permission/RLS error
      if (e.toString().contains('permission') || 
          e.toString().contains('RLS') ||
          e.toString().contains('PGRST301') ||
          e.toString().contains('PGRST116')) {
        throw Exception('Permission denied. You may not have permission to update this user due to Row Level Security (RLS) policies. Please create an update_user_status RPC function in your database to bypass RLS.');
      }
      rethrow;
    }
  }
}

