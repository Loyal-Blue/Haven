import 'package:material_ui/material_ui.dart';

import 'design.dart';
import 'domain.dart';
import 'editors.dart';
import 'store.dart';
import 'reminders.dart';

class HavenActions {
  const HavenActions(this.store);
  final HavenStore store;

  Future<HavenState?> run(
    BuildContext context,
    HavenState Function(HavenState) change, {
    String? success,
  }) async {
    try {
      final result = await store.commit(change);
      if (context.mounted && success != null) showNotice(context, success);
      return result;
    } on RuleFailure catch (error) {
      if (context.mounted) showNotice(context, error.message);
    } catch (error, stack) {
      debugPrintStack(
        label: 'Haven could not save a change (${error.runtimeType}).',
        stackTrace: stack,
      );
      if (context.mounted) {
        showNotice(context, 'Could not save the change. Try again.');
      }
    }
    return null;
  }

  Future<void> changeTask(
    BuildContext context,
    String day, [
    Task? task,
    String? projectId,
    Repeat initialRepeat = Repeat.once,
  ]) async {
    final edited = await editTask(
      context,
      day,
      task,
      store.state.projects,
      projectId,
      initialRepeat,
    );
    if (edited == null || !context.mounted) return;
    final saved = await run(
      context,
      (state) => state.copyWith(
        tasks: [
          for (final old in state.tasks)
            if (old.id == edited.id) edited else old,
          if (task == null) edited,
        ],
      ),
    );
    if (saved != null &&
        edited.reminderMinute != null &&
        edited.reminderMinute != task?.reminderMinute) {
      await TaskReminders().sync(saved, DateTime.now(), askPermission: true);
    }
  }

  Future<void> finishTask(BuildContext context, Task task) async {
    final now = DateTime.now();
    var completed = false;
    final result = await run(context, (state) {
      final next = completeTask(advanceTownExpansion(state, now), task.id, now);
      completed = !identical(state, next);
      return next;
    });
    if (result != null && completed && context.mounted) {
      showNotice(
        context,
        'Task completed.',
        icon: phoneStyle(context) == null ? null : Icons.auto_awesome_rounded,
      );
    }
  }

  Future<void> archiveTask(BuildContext context, Task task) async {
    final allowed = await confirmRemoval(
      context,
      'Archive task?',
      task.title,
      'Archive',
    );
    if (!allowed || !context.mounted) return;
    await run(
      context,
      (state) => state.copyWith(
        tasks: [
          for (final old in state.tasks)
            if (old.id == task.id) old.archive(dayKey(DateTime.now())) else old,
        ],
      ),
    );
  }

  Future<void> changeMoney(
    BuildContext context,
    String day, [
    MoneyEntry? entry,
  ]) async {
    final edited = await editMoney(context, day, entry);
    if (edited == null || !context.mounted) return;
    await run(
      context,
      (state) => state.copyWith(
        money: [
          for (final old in state.money)
            if (old.id == edited.id) edited else old,
          if (entry == null) edited,
        ],
      ),
    );
  }

  Future<void> deleteMoney(BuildContext context, MoneyEntry entry) async {
    final allowed = await confirmRemoval(
      context,
      'Delete transaction?',
      entry.label,
      'Delete',
    );
    if (!allowed || !context.mounted) return;
    await run(
      context,
      (state) => state.copyWith(
        money: state.money.where((item) => item.id != entry.id).toList(),
      ),
    );
  }

  Future<void> changeBudget(
    BuildContext context,
    String month,
    int current,
  ) async {
    final amount = await editBudget(context, current);
    if (amount == null || !context.mounted) return;
    await run(
      context,
      (state) => state.copyWith(budgets: {...state.budgets, month: amount}),
    );
  }

  Future<void> changeHobby(BuildContext context, [Hobby? hobby]) async {
    final edited = await editHobby(context, hobby);
    if (edited == null || !context.mounted) return;
    await run(
      context,
      (state) => state.copyWith(
        hobbies: [
          for (final old in state.hobbies)
            if (old.id == edited.id) edited else old,
          if (hobby == null) edited,
        ],
      ),
    );
  }

  Future<void> archiveHobby(BuildContext context, Hobby hobby) async {
    final allowed = await confirmRemoval(
      context,
      'Archive hobby?',
      hobby.name,
      'Archive',
    );
    if (!allowed || !context.mounted) return;
    await run(
      context,
      (state) => state.copyWith(
        hobbies: [
          for (final old in state.hobbies)
            if (old.id == hobby.id)
              Hobby(old.id, old.name, old.weeklyMinutes, true)
            else
              old,
        ],
      ),
    );
  }

  Future<void> practice(BuildContext context, Hobby hobby) async {
    final session = await logPractice(context, hobby);
    if (session == null || !context.mounted) return;
    await run(
      context,
      (state) => addPractice(state, session),
      success: 'Practice saved.',
    );
  }

  Future<void> rename(BuildContext context, String current) async {
    final name = await renameTown(context, current);
    if (name == null || !context.mounted) return;
    await run(context, (state) => state.copyWith(townName: name));
  }
}
