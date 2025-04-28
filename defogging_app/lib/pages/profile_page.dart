import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import '../models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfilePage extends StatefulWidget {
  final SharedPreferences prefs;

  const ProfilePage({super.key, required this.prefs});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  late final UserProfileService _userProfileService;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _userProfileService = UserProfileService(widget.prefs);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _userProfileService.getCurrentUserProfile();
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _displayNameController.text = profile.displayName ?? '';
          _phoneNumberController.text = profile.phoneNumber ?? '';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户资料失败: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        if (_userProfile != null) {
          final updatedProfile = _userProfile!.copyWith(
            displayName: _displayNameController.text,
            phoneNumber: _phoneNumberController.text,
          );
          await _userProfileService.createOrUpdateUserProfile(updatedProfile);
          setState(() {
            _userProfile = updatedProfile;
            _isEditing = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('资料更新成功')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('更新资料失败: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userProfile == null) {
      return const Center(child: Text('未找到用户资料'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人资料'),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _userProfile!.photoURL != null
                          ? NetworkImage(_userProfile!.photoURL!)
                          : null,
                      child: _userProfile!.photoURL == null
                          ? const Icon(Icons.person, size: 50)
                          : null,
                    ),
                    if (_isEditing)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, color: Colors.white),
                            onPressed: () {
                              // TODO: 实现头像上传功能
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: '显示名称',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入显示名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneNumberController,
                decoration: const InputDecoration(
                  labelText: '手机号码',
                  border: OutlineInputBorder(),
                ),
                enabled: _isEditing,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(r'^\+?[\d\s-]{10,}$').hasMatch(value)) {
                      return '请输入有效的手机号码';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('邮箱'),
                subtitle: Text(_userProfile!.email),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('注册时间'),
                subtitle: Text(_userProfile!.createdAt.toString()),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('最后登录'),
                subtitle: Text(_userProfile!.lastLoginAt.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 