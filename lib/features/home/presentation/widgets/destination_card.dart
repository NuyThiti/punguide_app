import 'package:flutter/material.dart';

import '../../../../shared/widgets/cover_image.dart';
import '../../domain/destination.dart';

class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
  });

  final Destination destination;
  final VoidCallback onTap;

  static const double width = 120;
  static const double height = 84;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (destination.coverImage case final image?)
                CoverImage(source: image, fit: BoxFit.cover)
              else
                const ColoredBox(color: Color(0xFFE6E2DC)),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.35, 1],
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.62),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    destination.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
