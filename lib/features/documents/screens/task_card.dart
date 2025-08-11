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
            _rowWithIcon(Icons.calendar_today, 'Дата создания: ${task.date}',
                color: Colors.blueGrey),
            const SizedBox(height: 8),
            _rowWithIcon(Icons.title, 'Название: ${task.name}',
                color: Colors.orange),
            const SizedBox(height: 4),
            _rowWithIcon(Icons.description, 'Описание: ${task.description}',
                color: Colors.teal),
            const SizedBox(height: 4),
            _rowWithIcon(Icons.timer_outlined, 'Время взятия: ${task.getTime}',
                color: Colors.deepPurple),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _rowWithIcon(Icons.person, 'Автор: ${task.author}',
                    color: Colors.indigo),
                _rowWithIcon(
                    Icons.assignment_ind, 'Кто взял: ${task.whoTake}',
                    color: Colors.teal),
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
                icon:
                Icon(task.isNew ? Icons.play_arrow : Icons.check),
                label: Text(
                    task.isNew ? 'Взять в работу' : 'Завершить задание'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                  task.isNew ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
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
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
