import 'package:flutter/material.dart';
import '../../domain/entities/event_entity.dart';
import '../../../runner/presentation/widgets/runner_widgets.dart';

class EventCard extends StatelessWidget {
  final EventEntity event;
  final VoidCallback onTap;
  final String? statusLabel;
  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    this.statusLabel,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RaceImage(event.bannerImage, height: 180),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(statusLabel ?? event.statusDisplay),
                const SizedBox(height: 10),
                Text(
                  event.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (event.tagline?.isNotEmpty == true) Text(event.tagline!),
                const SizedBox(height: 8),
                Text(event.location),
                Text(
                  '${calendarDate(event.date)}${event.endDate == null ? '' : ' – ${calendarDate(event.endDate)}'}',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: event.distanceTypes
                      .map(
                        (s) => Chip(
                          label: Text(s),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
