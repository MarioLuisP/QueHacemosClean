// lib/src/widgets/app_bars/main_app_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../contact_modal.dart';
import '../../providers/auth_provider.dart';
import 'components/notifications_bell.dart';
import '../login_modal.dart';

class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final List<Widget>? customActions;
  final bool showUserAvatar;
  final bool showNotifications;
  final bool showContactButton;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double elevation;
  final bool centerTitle;
  final double toolbarHeight;

  const MainAppBar({
    super.key,
    this.title,
    this.customActions,
    this.showUserAvatar = true,
    this.showNotifications = true,
    this.showContactButton = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 2.0,
    this.centerTitle = true,
    this.toolbarHeight = kToolbarHeight,
  });

  const MainAppBar.home({
    super.key,
    this.title = 'QuehaCeMos Córdoba',
    this.customActions,
    this.showUserAvatar = true,
    this.showNotifications = true,
    this.showContactButton = true,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 2.0,
    this.centerTitle = true,
    this.toolbarHeight = kToolbarHeight,
  });

  const MainAppBar.internal({
    super.key,
    required this.title,
    this.customActions,
    this.showUserAvatar = false,
    this.showNotifications = false,
    this.showContactButton = false,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation = 2.0,
    this.centerTitle = true,
    this.toolbarHeight = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    final appBarBgColor = backgroundColor ?? Theme.of(context).appBarTheme.backgroundColor;
    final appBarFgColor = foregroundColor ?? Theme.of(context).appBarTheme.foregroundColor;

    return AppBar(
      title: _buildTitle(context),
      centerTitle: centerTitle,
      toolbarHeight: preferredSize.height,
      elevation: elevation,
      backgroundColor: appBarBgColor,
      foregroundColor: appBarFgColor,
      titleSpacing: 0,
      actions: _buildActions(context, appBarFgColor),
    );
  }

  Widget _buildTitle(BuildContext context) {
    if (title == null) return const SizedBox.shrink();

    if (title == 'QuehaCeMos Córdoba') {
      return LayoutBuilder(
        builder: (context, constraints) {
          return Text(
            title!,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'Nunito',
              fontWeight: FontWeight.bold,
              fontSize: _getResponsiveFontSize(title!, constraints.maxWidth),
              color: foregroundColor ?? Theme.of(context).appBarTheme.foregroundColor,
            ),
          );
        },
      );
    }

    return Text(
      title!,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      maxLines: 1,
      style: TextStyle(
        fontFamily: 'Nunito',
        fontWeight: FontWeight.bold,
        fontSize: 22.0,
        color: foregroundColor ?? Theme.of(context).appBarTheme.foregroundColor,
      ),
    );
  }

  double _getResponsiveFontSize(String title, double availableWidth) {
    if (availableWidth < 150) return 16.0;
    if (availableWidth < 200) return 18.0;
    if (availableWidth < 280) return 19.0;
    return 20.0;
  }

  List<Widget> _buildActions(BuildContext context, Color? foregroundColor) {
    final List<Widget> actions = [];

    if (customActions != null) {
      actions.addAll(customActions!);
    }

    if (showContactButton) {
      actions.add(
        Transform.translate(
          offset: const Offset(0.0, 0),
          child: _ContactButtonSimple(iconColor: foregroundColor),
        ),
      );
    }

    if (showNotifications) {
      actions.add(
        Transform.translate(
          offset: const Offset(-6.0, 0),
          child: NotificationsBell(),
        ),
      );
    }

    if (showUserAvatar) {
      actions.add(
        Transform.translate(
          offset: const Offset(-2.0, 0),
          child: _UserAvatarReal(iconColor: foregroundColor),
        ),
      );
    }

    return actions;
  }

  @override
  Size get preferredSize => Size.fromHeight(toolbarHeight);
}

class _ContactButtonSimple extends StatelessWidget {
  final Color? iconColor;

  const _ContactButtonSimple({this.iconColor});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;

    return IconButton(
      onPressed: () {
        ContactModal.show(context);
      },
      icon: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withAlpha(38),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(77), width: 1),
        ),
        child: Icon(
          Icons.phone_forwarded,
          color: color,
          size: 18,
        ),
      ),
      tooltip: 'Publicar evento',
    );
  }
}

class _UserAvatarReal extends StatelessWidget {
  final Color? iconColor;

  const _UserAvatarReal({this.iconColor});

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Colors.white;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return _buildLoadingAvatar(color);
        }

        return IconButton(
          onPressed: () => _handleAvatarTap(context, authProvider),
          icon: _buildAvatarIcon(authProvider, color),
          tooltip: authProvider.isLoggedIn
              ? 'Mi cuenta'
              : 'Iniciar sesión',
        );
      },
    );
  }

  Widget _buildLoadingAvatar(Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ),
    );
  }

  void _handleAvatarTap(BuildContext context, AuthProvider authProvider) {
    if (authProvider.isLoggedIn) {
      _showLogoutModal(context, authProvider);
    } else {
      _showLoginModal(context, authProvider);
    }
  }

  Widget _buildAvatarIcon(AuthProvider authProvider, Color color) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 36,
          maxHeight: 36,
        ),
        decoration: BoxDecoration(
          color: authProvider.getAvatarColor(),
          shape: BoxShape.circle,
          border: Border.all(color: color.withAlpha(77), width: 2),
        ),
        child: _buildAvatarContent(authProvider, color),
      ),
    );
  }

  Widget _buildAvatarContent(AuthProvider authProvider, Color color) {
    if (authProvider.userPhotoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          authProvider.userPhotoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackAvatar(authProvider, color);
          },
        ),
      );
    }

    return _buildFallbackAvatar(authProvider, color);
  }

  Widget _buildFallbackAvatar(AuthProvider authProvider, Color color) {
    return Center(
      child: authProvider.isLoggedIn
          ? Text(
        authProvider.userInitials,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      )
          : Icon(
        Icons.person,
        color: color,
        size: 20,
      ),
    );
  }

  void _showLoginModal(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => LoginModal(authProvider: authProvider),
    );
  }

  void _showLogoutModal(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => _LogoutModal(authProvider: authProvider),
    );
  }
}

class _LogoutModal extends StatelessWidget {
  final AuthProvider authProvider;

  const _LogoutModal({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        children: [
          Text(
            authProvider.userEmail,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
      content: const Text('¿Querés cerrar sesión?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: authProvider.isLoading ? null : () async {
            await authProvider.signOut();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: authProvider.isLoading
              ? const Text('Cerrando...')
              : const Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

class CalendarAppBar extends MainAppBar {
  const CalendarAppBar({super.key, String? title, List<Widget>? customActions})
      : super(
    title: title ?? 'Elije el Día',
    customActions: customActions,
    showUserAvatar: true,
    showNotifications: true,
    showContactButton: false,
    centerTitle: true,
    toolbarHeight: 40.0,
  );
}

class ExploreAppBar extends MainAppBar {
  const ExploreAppBar({super.key, String? title, List<Widget>? customActions})
      : super(
    title: title ?? 'Busca Eventos',
    customActions: customActions,
    showUserAvatar: true,
    showNotifications: true,
    showContactButton: false,
    centerTitle: true,
    toolbarHeight: 40.0,
  );
}

class FavoritesAppBar extends MainAppBar {
  const FavoritesAppBar({super.key, String? title, List<Widget>? customActions})
      : super(
    title: title ?? 'Mis Favoritos',
    customActions: customActions,
    showUserAvatar: true,
    showNotifications: false,
    showContactButton: false,
    centerTitle: true,
    toolbarHeight: 40.0,
  );
}