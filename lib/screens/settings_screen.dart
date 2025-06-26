import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:message_cal/services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkSignInStatus();
  }

  Future<void> _checkSignInStatus() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      print('SETTINGS_SCREEN: Checking sign-in status...');
      
      // 먼저 현재 로그인 상태 확인
      bool isSignedIn = await _authService.isSignedIn();
      
      if (!isSignedIn) {
        print('SETTINGS_SCREEN: Not signed in, attempting silent sign-in...');
        // 로그인되어 있지 않다면 자동 로그인 시도
        final account = await _authService.signInSilently();
        if (account != null) {
          _currentUser = account;
          print('SETTINGS_SCREEN: Silent sign-in successful: ${account.email}');
        } else {
          print('SETTINGS_SCREEN: Silent sign-in failed');
          _currentUser = null;
        }
      } else {
        _currentUser = _authService.getCurrentUser();
        print('SETTINGS_SCREEN: Already signed in: ${_currentUser?.email}');
      }
    } catch (e) {
      print('SETTINGS_SCREEN: Error checking sign-in status: $e');
      _currentUser = null;
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.signInWithGoogle();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        _showSuccessSnackBar('Google 계정으로 로그인되었습니다');
      } else {
        _showErrorSnackBar('로그인에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      _showErrorSnackBar('로그인 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSignOut() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.signOut();
      setState(() {
        _currentUser = null;
      });
      _showSuccessSnackBar('로그아웃되었습니다');
    } catch (e) {
      _showErrorSnackBar('로그아웃 중 오류가 발생했습니다: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Google Account Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google 계정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('처리 중...', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  else if (_currentUser == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange.shade600),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Google 캘린더와 동기하려면 로그인이 필요합니다.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _handleSignIn,
                            icon: const Icon(Icons.login),
                            label: const Text('Google로 로그인'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade600),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Google 계정에 연결되어 캘린더 동기화가 활성화되었습니다.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundImage: _currentUser!.photoUrl != null
                                    ? NetworkImage(_currentUser!.photoUrl!)
                                    : null,
                                child: _currentUser!.photoUrl == null
                                    ? const Icon(Icons.person, size: 30)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _currentUser!.displayName ?? '이름 없음',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _currentUser!.email,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '연결됨',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isLoading ? null : _handleSignOut,
                            icon: const Icon(Icons.logout),
                            label: const Text('로그아웃'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.red.shade300),
                              foregroundColor: Colors.red.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // App Settings Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '앱 설정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text('알림 설정'),
                    subtitle: const Text('일정 알림 시간 설정'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement notification settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('알림 설정 기능은 추후 추가될 예정입니다'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.category),
                    title: const Text('카테고리 관리'),
                    subtitle: const Text('사용자 정의 카테고리 추가/삭제'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement category management
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('카테고리 관리 기능은 추후 추가될 예정입니다'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('테마 설정'),
                    subtitle: const Text('라이트/다크 모드'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement theme settings
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('테마 설정 기능은 추후 추가될 예정입니다'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // About Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '앱 정보',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('버전 정보'),
                    subtitle: const Text('v1.0.0+1'),
                    onTap: () {},
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.help),
                    title: const Text('도움말 및 지원'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement help screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('도움말 기능은 추후 추가될 예정입니다'),
                        ),
                      );
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip),
                    title: const Text('개인정보 처리방침'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // TODO: Implement privacy policy
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('개인정보 처리방침은 추후 추가될 예정입니다'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
