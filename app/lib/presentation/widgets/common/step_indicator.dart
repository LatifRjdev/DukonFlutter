import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';

class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? labels;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels,
  }) : assert(
          labels == null || labels.length == totalSteps,
          'labels length must equal totalSteps',
        );

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        // Even indices are step circles; odd indices are connecting lines.
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          return _StepCircle(
            stepNumber: stepIndex + 1,
            state: _stateFor(stepIndex),
            label: labels != null ? labels![stepIndex] : null,
          );
        } else {
          final lineIndex = index ~/ 2;
          return _ConnectingLine(
            isCompleted: lineIndex < currentStep,
          );
        }
      }),
    );
  }

  _StepState _stateFor(int stepIndex) {
    if (stepIndex < currentStep) return _StepState.completed;
    if (stepIndex == currentStep) return _StepState.active;
    return _StepState.upcoming;
  }
}

enum _StepState { completed, active, upcoming }

class _StepCircle extends StatelessWidget {
  final int stepNumber;
  final _StepState state;
  final String? label;

  const _StepCircle({
    required this.stepNumber,
    required this.state,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppConstants.animationNormal,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _backgroundColor,
            border: state == _StepState.upcoming
                ? Border.all(color: AppColors.disabled, width: 1.5)
                : null,
          ),
          child: Center(child: _innerContent),
        ),
        if (label != null) ...[
          const SizedBox(height: AppConstants.spacingXs),
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight:
                  state == _StepState.active ? FontWeight.w600 : FontWeight.w400,
              color: state == _StepState.upcoming
                  ? AppColors.textHint
                  : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Color get _backgroundColor {
    switch (state) {
      case _StepState.completed:
        return AppColors.primary;
      case _StepState.active:
        return AppColors.primary;
      case _StepState.upcoming:
        return Colors.transparent;
    }
  }

  Widget get _innerContent {
    switch (state) {
      case _StepState.completed:
        return const Icon(Icons.check, size: 18, color: Colors.white);
      case _StepState.active:
        return Text(
          '$stepNumber',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter',
            color: Colors.white,
          ),
        );
      case _StepState.upcoming:
        return Text(
          '$stepNumber',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
            color: AppColors.disabled,
          ),
        );
    }
  }
}

class _ConnectingLine extends StatelessWidget {
  final bool isCompleted;

  const _ConnectingLine({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingSm),
        child: AnimatedContainer(
          duration: AppConstants.animationNormal,
          height: 2,
          decoration: BoxDecoration(
            color: isCompleted ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
    );
  }
}
