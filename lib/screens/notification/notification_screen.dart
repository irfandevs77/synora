import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/notification_controller.dart';
import '../../models/notification_model.dart';
import '../../widgets/notification/notification_card.dart';
import '../profile/user_profile_screen.dart';
import '../chat/chat_screen.dart';

/// Premium Dark UI Color Palette for Synora
class SynoraColors {
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const primary = Color(0xFF5A4BFF);
  static const textPrimary = Color(0xFF17213D);
  static const textSecondary = Color(0xFF8495B2);
  static const accentRed = Color(0xFFFF4842);
  static const divider = Color(0xFF252D37);
}

class NotificationScreen extends StatelessWidget {
  final String currentUserId;
  final NotificationController controller = Get.put(NotificationController());

  NotificationScreen({super.key, required this.currentUserId}) {
    controller.initNotificationEngine(currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SynoraColors.background,
      appBar: AppBar(
        backgroundColor: SynoraColors.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: SynoraColors.textPrimary, size: 19),
        ),
        title: const Text('Notifications', style: TextStyle(color: SynoraColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.notifications.isEmpty) {
          return _buildEmptyState();
        }

        if (controller.notifications.isEmpty) {
          return _buildEmptyState();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _buildCategoryChips(),
            const SizedBox(height: 12),
            ...controller.notifications.map(_buildDismissibleCard),
          ],
        );
      }),
    );
  }

  Widget _buildCategoryChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        _categoryChip('All', true),
        _categoryChip('Messages', false),
        _categoryChip('Friends', false),
        _categoryChip('XP', false),
        _categoryChip('System', false),
      ]),
    );
  }

  Widget _categoryChip(String label, bool selected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: selected ? SynoraColors.primary : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? SynoraColors.primary : const Color(0xFFE5EAF2))),
      child: Text(label, style: TextStyle(color: selected ? Colors.white : SynoraColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.notifications_none_rounded, color: SynoraColors.primary, size: 56),
      const SizedBox(height: 14),
      const Text('No notifications yet', style: TextStyle(color: SynoraColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Friend requests, messages and updates\nwill appear here.', textAlign: TextAlign.center, style: TextStyle(color: SynoraColors.textSecondary, height: 1.45)),
    ])));
  }

  Widget _buildDismissibleCard(NotificationModel notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.horizontal,
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: SynoraColors.primary,
        icon: Icons.mark_chat_read,
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: SynoraColors.accentRed,
        icon: Icons.delete_outline,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await controller.markAsRead(notification.id);
          return false;
        } else {
          await controller.deleteNotification(notification.id);
          return true;
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: SynoraColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            NotificationCard(
              notification: notification,
              onTap: () {
                controller.markAsRead(notification.id);
                _handleNavigation(notification);
              },
              onMenuActionSelected: (action) {
                if (action == 'delete') {
                  controller.deleteNotification(notification.id);
                } else if (action == 'details') {
                  _handleNavigation(notification);
                }
              },
            ),
            if (notification.type == SynoraNotificationType.friendRequest)
              _buildFriendRequestButtons(notification),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendRequestButtons(NotificationModel notification) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SynoraColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => controller.acceptFriendRequest(
                  notificationId: notification.id,
                  senderId: notification.senderId,
                ),
                child: const Text(
                  'Accept',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 38,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF374151), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => controller.rejectFriendRequest(
                  notificationId: notification.id,
                  senderId: notification.senderId,
                ),
                child: const Text(
                  'Decline',
                  style: TextStyle(
                    color: SynoraColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }

  void _handleNavigation(NotificationModel notification) {
    switch (notification.type) {
      case SynoraNotificationType.friendRequest:
        Get.to(() => UserProfileScreen(userId: notification.senderId));
        break;
      case SynoraNotificationType.friendAccept:
        Get.to(() => UserProfileScreen(userId: notification.senderId));
        break;
      case SynoraNotificationType.message:
        if (notification.actionId != null &&
            notification.actionId!.isNotEmpty) {
          Get.to(
            () => ChatScreen(
              chatId: notification.actionId!,
              receiverId: notification.senderId,
              currentUserId: notification.receiverId,
            ),
          );
        }
        break;
      default:
        break;
    }
  }
}
