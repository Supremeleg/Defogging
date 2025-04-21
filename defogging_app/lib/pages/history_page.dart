import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10, // 示例数据
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue[100],
                child: const Icon(Icons.history, color: Colors.blue),
              ),
              title: Text('记录 ${index + 1}'),
              subtitle: Text('2024-${(index % 12) + 1}-${(index % 28) + 1}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                // TODO: 处理点击事件
              },
            ),
          );
        },
      ),
    );
  }
} 