import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/notification_model.dart';

/// Centralized Design Tokens mimicking premium Synora Palette Configurations.
class SynoraColors {
  static const Color primary = Color(0xFF5A4BFF);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF17213D);
  static const Color textSecondary = Color(0xFF8495B2);
  static const Color accentRed = Color(0xFFEF4444);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color border = Color(0xFFE5EAF2);
  static const Color bgDefault = Color(0xFFF8FAFC);
}

/// A highly-optimized, adaptive enterprise-grade Stateless card widget.
/// Renders premium dark UI context layers using glassmorphic blurring, robust clip areas,
/// clear layout constraint guarantees, explicit type-icons, and contextual responsive overlays.
class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final Function(String action)? onMenuActionSelected;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onMenuActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isUnread = !notification.isRead;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            decoration: BoxDecoration(
              color: isUnread
                  ? SynoraColors.primary.withValues(alpha: 0.07)
                  : SynoraColors.surface.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isUnread
                    ? SynoraColors.primary.withValues(alpha: 0.35)
                    : SynoraColors.border.withValues(alpha: 0.25),
                width: 1.2,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                onLongPress: () => _triggerHapticAndMenu(context),
                borderRadius: BorderRadius.circular(18),
                splashColor: SynoraColors.primary.withValues(alpha: 0.15),
                highlightColor: SynoraColors.primary.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIdentityAvatar(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: SynoraColors.textPrimary,
                                      fontWeight: isUnread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: deviceWidth > 600 ? 16 : 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildMetaTrackers(),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              notification.body,
                              style: TextStyle(
                                color: isUnread
                                    ? SynoraColors.textPrimary.withValues(alpha: 0.9)
                                    : SynoraColors.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildPopupMenuAnchor(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _triggerHapticAndMenu(BuildContext context) {
    HapticFeedback.mediumImpact();
    if (onMenuActionSelected != null) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final Offset offset = renderBox.localToGlobal(Offset.zero);
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx + renderBox.size.width,
            offset.dy,
            offset.dx + renderBox.size.width,
            offset.dy,
          ),
          items: [
            PopupMenuItem<String>(
              value: 'mark_read',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: SynoraColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.isRead ? 'Mark as Unread' : 'Mark as Read',
                    style: TextStyle(color: SynoraColors.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: SynoraColors.accentRed,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Delete',
                    style: TextStyle(color: SynoraColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ).then((String? action) {
          if (action != null) onMenuActionSelected!(action);
        });
      }
    }
  }

  Widget _buildIdentityAvatar() {
    final senderPhoto = notification.senderPhoto?.trim();
    final hasSenderPhoto = senderPhoto != null && senderPhoto.isNotEmpty;

    return Hero(
      tag: 'notification_avatar_${notification.id}',
      flightShuttleBuilder:
          (
            flightContext,
            animation,
            flightDirection,
            fromHeroContext,
            toHeroContext,
          ) {
            return const SizedBox.shrink();
          },
      child: CircleAvatar(
        radius: 22,
        backgroundColor: SynoraColors.surface.withValues(alpha: 0.6),
        backgroundImage: hasSenderPhoto
            ? CachedNetworkImageProvider(senderPhoto)
            : null,
        child: !hasSenderPhoto
            ? Icon(
                Icons.notifications_outlined,
                color: SynoraColors.textSecondary,
                size: 22,
              )
            : null,
      ),
    );
  }

  Widget _buildMetaTrackers() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _priorityColor(notification.priority).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            notification.priority.name.toUpperCase(),
            style: TextStyle(
              color: _priorityColor(notification.priority),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (!notification.isRead)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: SynoraColors.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Color _priorityColor(SynoraNotificationPriority priority) {
    switch (priority) {
      case SynoraNotificationPriority.high:
        return SynoraColors.accentRed;
      case SynoraNotificationPriority.normal:
        return SynoraColors.accentAmber;
      case SynoraNotificationPriority.low:
        return SynoraColors.textSecondary;
    }
  }

  Widget _buildPopupMenuAnchor(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) => _showPopupMenu(context, details),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(
          Icons.more_vert,
          color: SynoraColors.textSecondary,
          size: 18,
        ),
      ),
    );
  }

  void _showPopupMenu(BuildContext context, TapDownDetails details) {
    HapticFeedback.lightImpact();
    if (onMenuActionSelected != null) {
      final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final Offset offset = renderBox.localToGlobal(details.globalPosition);
        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy,
            offset.dx,
            offset.dy,
          ),
          items: [
            PopupMenuItem<String>(
              value: 'mark_read',
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: SynoraColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    notification.isRead ? 'Mark as Unread' : 'Mark as Read',
                    style: TextStyle(color: SynoraColors.textPrimary),
                  ),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: SynoraColors.accentRed,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Delete',
                    style: TextStyle(color: SynoraColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ).then((String? action) {
          if (action != null) onMenuActionSelected!(action);
        });
      }
    }
  }
}
