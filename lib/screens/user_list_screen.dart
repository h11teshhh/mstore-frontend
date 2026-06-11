import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import '../api/api_service.dart';
import '../storage/token_storage.dart';
import '../utils/app_constants.dart';
import '../utils/ui_utils.dart';
import '../utils/skeletal_loader.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final ApiService api = ApiService();
  final TokenStorage storage = TokenStorage();
  final TextEditingController searchController = TextEditingController();

  bool loading = true;
  List<dynamic> allUsers = [];
  List<dynamic> filteredUsers = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  @override
  void dispose() {
    searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> fetchUsers() async {
    setState(() => loading = true);
    try {
      final response = await api.getUsers();
      if (!mounted) return;
      setState(() {
        allUsers = (response.data ?? [])
            .where((u) => u["is_active"] == true)
            .toList();
        filteredUsers = allUsers;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        if (query.isEmpty) {
          filteredUsers = allUsers;
        } else {
          filteredUsers = allUsers.where((u) {
            final name = u["name"].toString().toLowerCase();
            final mobile = u["mobile"].toString();
            return name.contains(query.toLowerCase()) ||
                mobile.contains(query);
          }).toList();
        }
      });
    });
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Delete User",
            style: TextStyle(
                color: AppColors.textHeading, fontWeight: FontWeight.bold)),
        content: Text(
            "Are you sure you want to delete \"$userName\"?\n\nThis action cannot be undone.",
            style: const TextStyle(color: AppColors.textDark)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel",
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await api.deleteUser(userId);
      UIUtils.showSuccessToast("User deleted successfully");
      fetchUsers();
    } catch (_) {}
  }

  Color _roleColor(String role) {
    switch (role) {
      case "SUPERADMIN":
        return AppColors.danger;
      case "ADMIN":
        return AppColors.primary;
      case "DELIVERY":
        return AppColors.info;
      default:
        return AppColors.secondary;
    }
  }

  Widget _buildUserCard(dynamic user) {
    final name   = user["name"] ?? "Unknown";
    final mobile = user["mobile"] ?? "N/A";
    final role   = user["role"] ?? "N/A";
    final id     = user["id"] ?? user["_id"] ?? "";
    final color  = _roleColor(role);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                name.toString().substring(0, 1).toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppColors.textHeading)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(mobile,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),

            // Role badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(role,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),

            // Delete button (not for SUPERADMIN role)
            if (role != "SUPERADMIN") ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteUser(id.toString(), name),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.delete_outline,
                      color: AppColors.danger, size: 18),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      children: List.generate(
          5, (_) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletalLoader(width: double.infinity, height: 76, borderRadius: 12),
              )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Manage Users"),
        systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchUsers,
            tooltip: "Refresh",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: "Search by name or mobile...",
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textMuted),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadius),
                    borderSide: BorderSide.none),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppColors.textMuted),
                        onPressed: () {
                          searchController.clear();
                          _onSearchChanged('');
                        })
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // List
            Expanded(
              child: loading
                  ? _buildSkeleton()
                  : filteredUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined,
                                  size: 60, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text("No users found",
                                  style: TextStyle(
                                      color: Colors.grey[500], fontSize: 16)),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchUsers,
                          color: AppColors.primary,
                          child: ListView.separated(
                            itemCount: filteredUsers.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _buildUserCard(filteredUsers[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
