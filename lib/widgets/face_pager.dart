import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/calendar_faces.dart';
import '../services/calendar_repository.dart';
import 'motion.dart';

IconData faceIcon(CalFace f) => switch (f) {
  CalFace.gregorian => Icons.public_rounded,
  CalFace.ethiopian => Icons.wb_sunny_rounded,
  CalFace.islamic => Icons.mosque_rounded,
  CalFace.orthodox => Icons.church_rounded,
};

/// Swipeable header of the glass widget: Gregorian · Ethiopian · Islamic ·
/// Orthodox. Wraps around endlessly and stays in sync with the repository so
/// the island and the home-screen widgets show the same calendar.
class FacePager extends StatefulWidget {
  const FacePager({
    super.key,
    required this.instanceId,
    this.height = 150,
    this.color = Colors.white,
  });

  /// Which widget instance this pager belongs to (each keeps its own face).
  final String instanceId;
  final double height;
  final Color color;

  @override
  State<FacePager> createState() => _FacePagerState();
}

class _FacePagerState extends State<FacePager> {
  static const _base =
      4000; // large multiple of 4 so we can swipe both ways forever
  late final PageController _pc;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page =
        _base +
        context.read<CalendarRepository>().faceOf(widget.instanceId).index;
    _pc = PageController(initialPage: _page);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<CalendarRepository>();
    // Face changed elsewhere (island swipe, settings): glide to it.
    if (_page % 4 != repo.faceOf(widget.instanceId).index &&
        _pc.hasClients &&
        !_pc.position.isScrollingNotifier.value) {
      final delta = (repo.faceOf(widget.instanceId).index - _page % 4 + 4) % 4;
      final target = _page + (delta == 3 ? -1 : delta);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _pc.animateToPage(
            target,
            duration: Motion.medium,
            curve: Motion.ease,
          );
        }
      });
      _page = target;
    }
    final c = widget.color;
    return SizedBox(
      height: widget.height,
      child: PageView.builder(
        controller: _pc,
        onPageChanged: (p) {
          _page = p;
          HapticFeedback.selectionClick();
          repo.setFaceFor(widget.instanceId, CalFace.values[p % 4]);
        },
        itemBuilder: (context, p) {
          final f = CalFace.values[p % 4];
          final v = faceView(f, repo.selectedDay);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: .16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(faceIcon(f), size: 14, color: c),
                          const SizedBox(width: 5),
                          Text(
                            v.label,
                            style: TextStyle(
                              color: c,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    for (var i = 0; i < 4; i++)
                      AnimatedContainer(
                        duration: Motion.fast,
                        margin: const EdgeInsets.only(left: 4),
                        width: i == f.index ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: i == f.index ? .95 : .4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          v.title,
                          style: TextStyle(
                            color: c,
                            fontSize: 40,
                            fontWeight: FontWeight.w300,
                            letterSpacing: -1.2,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      v.day,
                      style: TextStyle(
                        color: c,
                        fontSize: 52,
                        fontWeight: FontWeight.w300,
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  v.line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.withValues(alpha: .9),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (v.line2.isNotEmpty)
                  Text(
                    v.line2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.withValues(alpha: .65),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
