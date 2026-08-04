import 'package:flutter/material.dart';

/// Custom physics for the inner ScheduleScreen PageView.
/// At week 1, passes right-swipe outward to parent PageView.
/// At week 20, passes left-swipe outward to parent PageView.
/// In between weeks, normal page-snap behavior.
class EdgeAwarePhysics extends PageScrollPhysics {
  final bool atLeftEdge;
  final bool atRightEdge;

  const EdgeAwarePhysics({
    this.atLeftEdge = false,
    this.atRightEdge = false,
    super.parent,
  });

  @override
  EdgeAwarePhysics applyTo(ScrollPhysics? ancestor) {
    return EdgeAwarePhysics(
      atLeftEdge: atLeftEdge,
      atRightEdge: atRightEdge,
      parent: buildParent(ancestor),
    );
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Always accept offset — PageView needs to track the drag
    return true;
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double offset) {
    // At left edge: allow right-swipe to overflow → passes to outer PageView
    if (atLeftEdge && offset > 0) {
      return offset;
    }
    // At right edge: allow left-swipe to overflow → passes to outer PageView
    if (atRightEdge && offset < 0) {
      return offset;
    }
    return super.applyBoundaryConditions(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(
      ScrollMetrics position, double velocity) {
    // At edge with outward velocity → no simulation → outer PageView takes over
    if (atLeftEdge && position.pixels <= position.minScrollExtent && velocity > 0) {
      return null;
    }
    if (atRightEdge && position.pixels >= position.maxScrollExtent && velocity < 0) {
      return null;
    }
    // Normally → PageScrollPhysics handles snap-to-page
    return super.createBallisticSimulation(position, velocity);
  }
}
