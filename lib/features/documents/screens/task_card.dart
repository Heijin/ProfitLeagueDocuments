import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final bool isCompleted;
  final VoidCallback onTake;
  final VoidCallback onComplete;

  const TaskCard({
    super.key,
    required this.task,
    required this.isCompleted,
    required this.onTake,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: task.isNew ? Colors.green.shade300 : Colors.red.shade300,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rowWithIcon(Icons.calendar_today, 'Дата создания: ${task.date}', color: Colors.blueGrey),
            const SizedBox(height: 8),
            _rowWithIcon(Icons.description_outlined, 'Документ основание: ${task.doc}', color: Colors.brown),
            const SizedBox(height: 8),
            _rowWithIcon(Icons.title, 'Название: ${task.name}', color: Colors.orange),
            const SizedBox(height: 4),
            _rowWithIconWithGoods(Icons.description, 'Описание: ${task.description}', task.goods, context, color: Colors.teal),
            const SizedBox(height: 4),
            _rowWithIcon(Icons.timer_outlined, 'Время взятия: ${task.getTime}', color: Colors.deepPurple),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: _rowWithIcon(Icons.assignment_ind, 'Кто взял: ${task.whoTake}', color: Colors.teal)),
                const SizedBox(width: 8),
                Expanded(child: _rowWithIcon(Icons.person, 'Автор: ${task.author}', color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: isCompleted
                  ? const Text(
                'Задача завершена',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : ElevatedButton.icon(
                onPressed: task.isNew ? onTake : onComplete,
                icon: Icon(task.isNew ? Icons.play_arrow : Icons.check),
                label: Text(task.isNew ? 'Взять в работу' : 'Завершить задание'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: task.isNew ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowWithIcon(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(child: Text(text)),
      ],
    );
  }

  Widget _rowWithIconWithGoods(IconData icon, String text, List<String> goods, BuildContext context, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
        if (goods.isNotEmpty)
          InkWell(
            onTap: () => _showGoodsDialog(context, goods),
            child: Padding(
              padding: const EdgeInsets.only(left: 4.0, top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shopping_cart, size: 20, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('Товары', style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showGoodsDialog(BuildContext context, List<String> goods) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Список товаров'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              itemCount: goods.length,
              itemBuilder: (context, index) {
                return ListTile(
                  dense: true,
                  leading: Text('${index + 1}.'),
                  title: Text(goods[index]),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}
