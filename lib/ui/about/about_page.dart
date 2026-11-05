import 'package:flutter/material.dart';

import 'about_info.dart';
import 'about_widgets.dart';
import 'github_profile.dart';
import 'licenses_page.dart';
import 'update_check.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      body: CustomScrollView(slivers: [
        const SliverAppBar(pinned: true, title: Text('About')),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Hero(),
                    const SizedBox(height: 12),
                    AboutQuickActions(items: [
                      QuickAction(
                        icon: const GithubIcon(),
                        label: 'GitHub',
                        onTap: () => openExternal(AboutInfo.repoUrl),
                      ),
                      QuickAction(
                        icon: const Icon(Icons.system_update_outlined),
                        label: 'Check For Update',
                        onTap: () => checkForUpdate(context),
                      ),
                      QuickAction(
                        icon: const Icon(Icons.bug_report_outlined),
                        label: 'Issues',
                        onTap: () => openExternal(AboutInfo.issuesUrl),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Text('Author',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const _AuthorCard(),
                    const SizedBox(height: 12),
                    AboutGroup(items: [
                      const AboutItem(
                        icon: Icons.info_outline,
                        title: 'Version',
                        subtitle: 'v${AboutInfo.displayVersion}',
                        chevron: false,
                      ),
                      AboutItem(
                        icon: Icons.description_outlined,
                        title: 'Open source licenses',
                        subtitle: 'Libraries used by this app',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LicensesPage()),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.music_note_rounded,
              size: 36, color: cs.onPrimaryContainer),
        ),
        const SizedBox(height: 16),
        Text(AboutInfo.name,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(AboutInfo.tagline,
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
      ]),
    );
  }
}

class _AuthorCard extends StatefulWidget {
  const _AuthorCard();

  @override
  State<_AuthorCard> createState() => _AuthorCardState();
}

class _AuthorCardState extends State<_AuthorCard> {
  static const _avatarSize = 112.0;
  late final Future<GithubProfile?> _profile =
      GithubProfile.load(AboutInfo.githubLogin);

  Widget _avatar(ColorScheme cs, String? url, String letter) {
    Widget fallback() => Container(
          width: _avatarSize,
          height: _avatarSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          child: Text(letter,
              style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimary)),
        );
    if (url == null) return fallback();
    return ClipOval(
      child: Image.network(
        url,
        width: _avatarSize,
        height: _avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
        loadingBuilder: (_, child, p) => p == null ? child : fallback(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainer,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: SizedBox(
          width: double.infinity,
          child: FutureBuilder<GithubProfile?>(
            future: _profile,
            builder: (context, snap) {
              final p = snap.data;
              final name = p?.name ?? AboutInfo.author;
              return Column(children: [
                _avatar(cs, p?.avatarUrl, name[0].toUpperCase()),
                const SizedBox(height: 16),
                Text(name,
                    textAlign: TextAlign.center,
                    style: text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(AboutInfo.authorRole,
                    textAlign: TextAlign.center,
                    style: text.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w400)),
                const SizedBox(height: 20),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: () => openExternal(AboutInfo.supportUrl),
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      label: const Text('Support my work'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    tooltip: 'GitHub profile',
                    iconSize: 28,
                    onPressed: () => openExternal(AboutInfo.profileUrl),
                    icon: const GithubIcon(size: 28),
                  ),
                ]),
              ]);
            },
          ),
        ),
      ),
    );
  }
}
