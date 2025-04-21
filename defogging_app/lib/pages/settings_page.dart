import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          _buildSection(
            '常规设置',
            [
              _buildSettingItem(
                icon: Icons.notifications_outlined,
                title: '消息通知',
                subtitle: '设置消息提醒方式',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.language_outlined,
                title: '语言设置',
                subtitle: '切换应用语言',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.dark_mode_outlined,
                title: '深色模式',
                subtitle: '切换应用主题',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            '数据设置',
            [
              _buildSettingItem(
                icon: Icons.storage_outlined,
                title: '数据存储',
                subtitle: '管理本地数据',
                onTap: () {},
              ),
              _buildSettingItem(
                icon: Icons.sync_outlined,
                title: '同步设置',
                subtitle: '配置数据同步选项',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            '其他',
            [
              _buildSettingItem(
                icon: Icons.info_outline,
                title: '关于',
                subtitle: '版本信息与说明',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: '除雾应用',
                    applicationVersion: '1.0.0',
                    applicationIcon: const FlutterLogo(size: 50),
                    children: const [
                      Text('这是一个用于除雾监测的应用程序。'),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
} 