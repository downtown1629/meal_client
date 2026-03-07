import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model.dart';
import '../string.dart' as string;

class HomeAnnouncementDialog extends StatelessWidget {
  final String close;
  final String title;
  final String content;

  const HomeAnnouncementDialog({
    super.key,
    required this.close,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/imgs/bapu_logo.svg',
            height: 24,
            colorFilter: ColorFilter.mode(
              theme.colorScheme.primaryContainer,
              BlendMode.srcIn,
            ),
          ),
          SizedBox(height: 10),
          Text(title),
        ],
      ),
      content: SingleChildScrollView(
        child: ListBody(children: [Text(content)]),
      ),
      actions: [
        TextButton(
          child: Text(close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      contentPadding: EdgeInsets.only(left: 40),
      onTap: onTap,
    );
  }
}

class HomePageDrawer extends StatelessWidget {
  const HomePageDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final language = Provider.of<BapUModel>(context).language;

    return Drawer(
      backgroundColor: brightness == Brightness.light
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainer,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.all(0),
              children: [
                Container(
                  height: 160,
                  alignment: Alignment.bottomLeft,
                  margin: EdgeInsets.only(bottom: 50, left: 40),
                  child: SvgPicture.asset('assets/imgs/bapu_logo.svg', height: 36),
                ),
                _DrawerItem(
                  icon: Icons.notifications_active,
                  title: string.announcement.getLocalizedString(language),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final sharedPreferences = await SharedPreferences.getInstance();
                    final announcement = sharedPreferences.getString("announceTime");
                    if (announcement != null && context.mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (BuildContext context) {
                          return HomeAnnouncementDialog(
                            close: string.close.getLocalizedString(language),
                            title: string.announcement.getLocalizedString(language),
                            content: announcement,
                          );
                        },
                      );
                    }
                  },
                ),
                _DrawerItem(
                  icon: Icons.info,
                  title: string.operationhours.getLocalizedString(language),
                  onTap: () {
                    Navigator.of(context).pop();
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return HomeAnnouncementDialog(
                          close: string.close.getLocalizedString(language),
                          title: string.operationhours.getLocalizedString(language),
                          content: string.operationhourscontent.getLocalizedString(
                            language,
                          ),
                        );
                      },
                    );
                  },
                ),
                _DrawerItem(
                  icon: Icons.help_outline_outlined,
                  title: string.contactdeveloper.getLocalizedString(language),
                  onTap: () async =>
                      await launchUrl(Uri.parse("https://pf.kakao.com/_xcaYlxj")),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 40, bottom: 12),
                child: IconButton(
                  icon: Icon(Icons.copyright, color: Colors.white),
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: "BapU",
                    applicationLegalese:
                        "Source code: https://github.com/HeXA-UNIST/meal_client",
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

