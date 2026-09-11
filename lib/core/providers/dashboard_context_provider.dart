import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class DashboardContext {
  const DashboardContext();
}

class FarmDashboardContext extends DashboardContext {
  const FarmDashboardContext();

  @override
  bool operator ==(Object other) => identical(this, other) || other is FarmDashboardContext;

  @override
  int get hashCode => runtimeType.hashCode;
}

class BatchDashboardContext extends DashboardContext {
  final String batchId;
  const BatchDashboardContext(this.batchId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is BatchDashboardContext && other.batchId == batchId);

  @override
  int get hashCode => batchId.hashCode;
}

class DashboardContextNotifier extends StateNotifier<DashboardContext> {
  DashboardContextNotifier() : super(const FarmDashboardContext());

  void selectFarm() {
    state = const FarmDashboardContext();
  }

  void selectBatch(String batchId) {
    state = BatchDashboardContext(batchId);
  }

  void setContext(DashboardContext context) {
    state = context;
  }
}

final dashboardContextProvider = StateNotifierProvider<DashboardContextNotifier, DashboardContext>((ref) {
  return DashboardContextNotifier();
});
