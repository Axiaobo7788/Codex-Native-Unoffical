import 'package:meta/meta.dart';

const maxPermissionProfiles = 32;
const maxConfigLayers = 16;
const maxHookEntries = 16;
const maxHooksPerWorkspace = 64;
const maxTotalDiagnosticsHooks = 64;
const maxHookDiagnosticsPerWorkspace = 16;
const maxRateLimitBuckets = 8;
const maxDiagnosticsAllowedItems = 16;
const maxDiagnosticsIdentifierLength = 256;
const maxDiagnosticsLabelLength = 256;
const maxDiagnosticsPathLength = 1024;
const maxDiagnosticsDescriptionLength = 512;

@immutable
final class AccountDiagnosticsSnapshot {
  const AccountDiagnosticsSnapshot({
    required this.requiresOpenaiAuth,
    required this.accountType,
    this.planType,
    this.email,
    this.workspaceName,
    this.usesCodexManagedCredentials,
    this.authMode,
  });

  final bool requiresOpenaiAuth;
  final String accountType;
  final String? planType;
  final String? email;
  final String? workspaceName;
  final bool? usesCodexManagedCredentials;
  final String? authMode;

  bool get isAuthenticated => accountType != 'unauthenticated';

  AccountDiagnosticsSnapshot copyWith({
    bool? requiresOpenaiAuth,
    String? accountType,
    String? planType,
    String? email,
    String? workspaceName,
    bool? usesCodexManagedCredentials,
    String? authMode,
  }) {
    return AccountDiagnosticsSnapshot(
      requiresOpenaiAuth: requiresOpenaiAuth ?? this.requiresOpenaiAuth,
      accountType: accountType ?? this.accountType,
      planType: planType ?? this.planType,
      email: email ?? this.email,
      workspaceName: workspaceName ?? this.workspaceName,
      usesCodexManagedCredentials:
          usesCodexManagedCredentials ?? this.usesCodexManagedCredentials,
      authMode: authMode ?? this.authMode,
    );
  }

  AccountDiagnosticsSnapshot applyAccountUpdated(
    AccountUpdatedDiagnosticsEvent event,
  ) {
    return copyWith(
      authMode: event.authMode ?? authMode,
      planType: event.planType ?? planType,
    );
  }
}

@immutable
final class RateLimitWindowSnapshot {
  const RateLimitWindowSnapshot({
    required this.usedPercent,
    this.windowDurationMins,
    this.resetsAtEpochSeconds,
  });

  final int usedPercent;
  final int? windowDurationMins;
  final int? resetsAtEpochSeconds;
}

@immutable
final class CreditsDiagnosticsSnapshot {
  const CreditsDiagnosticsSnapshot({
    required this.hasCredits,
    required this.unlimited,
    this.balance,
  });

  final bool hasCredits;
  final bool unlimited;
  final String? balance;
}

@immutable
final class SpendControlDiagnosticsSnapshot {
  const SpendControlDiagnosticsSnapshot({
    required this.limit,
    required this.used,
    required this.remainingPercent,
    required this.resetsAtEpochSeconds,
  });

  final String limit;
  final String used;
  final int remainingPercent;
  final int resetsAtEpochSeconds;
}

@immutable
final class RateLimitBucketSnapshot {
  const RateLimitBucketSnapshot({
    this.limitId,
    this.limitName,
    this.normalModelSlug,
    this.planType,
    this.primary,
    this.secondary,
    this.credits,
    this.individualLimit,
    this.rateLimitReachedType,
    this.spendControlReached,
  });

  final String? limitId;
  final String? limitName;
  final String? normalModelSlug;
  final String? planType;
  final RateLimitWindowSnapshot? primary;
  final RateLimitWindowSnapshot? secondary;
  final CreditsDiagnosticsSnapshot? credits;
  final SpendControlDiagnosticsSnapshot? individualLimit;
  final String? rateLimitReachedType;
  final bool? spendControlReached;

  /// Merges a sparse rolling `account/rateLimits/updated` payload without
  /// clearing previously observed nullable metadata when omitted.
  RateLimitBucketSnapshot mergeSparseUpdate(RateLimitBucketSnapshot update) {
    return RateLimitBucketSnapshot(
      limitId: update.limitId ?? limitId,
      limitName: update.limitName ?? limitName,
      normalModelSlug: update.normalModelSlug ?? normalModelSlug,
      planType: update.planType ?? planType,
      primary: update.primary ?? primary,
      secondary: update.secondary ?? secondary,
      credits: update.credits ?? credits,
      individualLimit: update.individualLimit ?? individualLimit,
      rateLimitReachedType: update.rateLimitReachedType ?? rateLimitReachedType,
      spendControlReached: update.spendControlReached ?? spendControlReached,
    );
  }
}

@immutable
final class RateLimitsDiagnosticsSnapshot {
  RateLimitsDiagnosticsSnapshot({
    required this.primaryBucket,
    List<RateLimitBucketSnapshot> bucketsById = const [],
    this.ordinaryUsageAllowed,
    this.availableResetCreditsCount,
  }) : bucketsById = List<RateLimitBucketSnapshot>.unmodifiable(
         bucketsById.take(maxRateLimitBuckets),
       );

  final RateLimitBucketSnapshot primaryBucket;
  final List<RateLimitBucketSnapshot> bucketsById;
  final bool? ordinaryUsageAllowed;
  final int? availableResetCreditsCount;

  RateLimitsDiagnosticsSnapshot applyRateLimitsUpdated(
    RateLimitBucketSnapshot update,
  ) {
    final mergedPrimary = primaryBucket.mergeSparseUpdate(update);
    final updatedBuckets = <RateLimitBucketSnapshot>[];
    var matchedBucket = false;
    for (final bucket in bucketsById) {
      if (update.limitId != null && bucket.limitId == update.limitId) {
        updatedBuckets.add(bucket.mergeSparseUpdate(update));
        matchedBucket = true;
      } else {
        updatedBuckets.add(bucket);
      }
    }
    if (!matchedBucket &&
        update.limitId != null &&
        updatedBuckets.length < maxRateLimitBuckets) {
      updatedBuckets.add(update);
    }
    return RateLimitsDiagnosticsSnapshot(
      primaryBucket: mergedPrimary,
      bucketsById: updatedBuckets,
      ordinaryUsageAllowed: ordinaryUsageAllowed,
      availableResetCreditsCount: availableResetCreditsCount,
    );
  }
}

@immutable
final class PermissionProfileSummaryModel {
  const PermissionProfileSummaryModel({
    required this.id,
    required this.allowed,
    this.description,
  });

  final String id;
  final bool allowed;
  final String? description;
}

@immutable
final class PermissionProfileListSnapshot {
  PermissionProfileListSnapshot({
    required List<PermissionProfileSummaryModel> profiles,
    this.nextCursor,
    this.hasMore = false,
  }) : profiles = List<PermissionProfileSummaryModel>.unmodifiable(
         profiles.take(maxPermissionProfiles),
       );

  final List<PermissionProfileSummaryModel> profiles;
  final String? nextCursor;
  final bool hasMore;
}

@immutable
final class ConfigLayerSummaryModel {
  const ConfigLayerSummaryModel({
    required this.sourceType,
    required this.version,
    required this.configEntryCount,
    this.sourceLocation,
    this.profile,
    this.disabledReason,
  });

  final String sourceType;
  final String version;
  final int configEntryCount;
  final String? sourceLocation;
  final String? profile;
  final String? disabledReason;
}

/// Bounded typed summary of `config/read`.
///
/// Raw `config`, `origins`, and per-layer `config` objects are discarded at
/// protocol parser ingress so unbounded user/enterprise configuration trees and
/// prompt strings are never retained in Flutter state.
@immutable
final class ConfigDiagnosticsSnapshot {
  ConfigDiagnosticsSnapshot({
    required this.configKeyCount,
    required this.originCount,
    List<ConfigLayerSummaryModel> layers = const [],
    this.model,
    this.reviewModel,
    this.modelProvider,
    this.modelReasoningEffort,
    this.modelReasoningSummary,
    this.modelVerbosity,
    this.approvalPolicy,
    this.approvalsReviewer,
    this.sandboxMode,
    this.serviceTier,
    this.webSearchMode,
    this.defaultPermissions,
    this.profile,
    this.modelContextWindow,
    this.modelAutoCompactTokenLimit,
  }) : layers = List<ConfigLayerSummaryModel>.unmodifiable(
         layers.take(maxConfigLayers),
       );

  final int configKeyCount;
  final int originCount;
  final List<ConfigLayerSummaryModel> layers;
  final String? model;
  final String? reviewModel;
  final String? modelProvider;
  final String? modelReasoningEffort;
  final String? modelReasoningSummary;
  final String? modelVerbosity;
  final String? approvalPolicy;
  final String? approvalsReviewer;
  final String? sandboxMode;
  final String? serviceTier;
  final String? webSearchMode;
  final String? defaultPermissions;
  final String? profile;
  final int? modelContextWindow;
  final int? modelAutoCompactTokenLimit;
}

@immutable
final class ConfigRequirementsSummaryModel {
  ConfigRequirementsSummaryModel({
    required this.hasRequirements,
    this.supportsIndependentSpeedModes,
    List<String> allowedApprovalPolicies = const [],
    List<String> allowedSandboxModes = const [],
    List<String> allowedWebSearchModes = const [],
    List<String> allowedLoginMethods = const [],
    this.defaultPermissions,
    this.modelProvider,
    this.enforceResidency,
    this.allowRemoteControl,
    this.allowManagedHooksOnly,
    this.allowLoginShell,
    this.allowBrowserAndComputerUse,
  }) : allowedApprovalPolicies = List<String>.unmodifiable(
         allowedApprovalPolicies.take(maxDiagnosticsAllowedItems),
       ),
       allowedSandboxModes = List<String>.unmodifiable(
         allowedSandboxModes.take(maxDiagnosticsAllowedItems),
       ),
       allowedWebSearchModes = List<String>.unmodifiable(
         allowedWebSearchModes.take(maxDiagnosticsAllowedItems),
       ),
       allowedLoginMethods = List<String>.unmodifiable(
         allowedLoginMethods.take(maxDiagnosticsAllowedItems),
       );

  final bool hasRequirements;
  final bool? supportsIndependentSpeedModes;
  final List<String> allowedApprovalPolicies;
  final List<String> allowedSandboxModes;
  final List<String> allowedWebSearchModes;
  final List<String> allowedLoginMethods;
  final String? defaultPermissions;
  final String? modelProvider;
  final String? enforceResidency;
  final bool? allowRemoteControl;
  final bool? allowManagedHooksOnly;
  final bool? allowLoginShell;
  final bool? allowBrowserAndComputerUse;
}

@immutable
final class ModelProviderCapabilitiesSnapshot {
  const ModelProviderCapabilitiesSnapshot({
    required this.imageGeneration,
    required this.webSearch,
  });

  final bool imageGeneration;
  final bool webSearch;
}

@immutable
final class HookSummaryModel {
  const HookSummaryModel({
    required this.key,
    required this.eventName,
    required this.handlerType,
    required this.enabled,
    required this.isManaged,
    required this.source,
    required this.sourcePath,
    required this.trustStatus,
    required this.timeoutSec,
    this.isAsync = false,
    this.targetSummary,
    this.matcher,
    this.statusMessage,
  });

  final String key;
  final String eventName;
  final String handlerType;
  final bool enabled;
  final bool isManaged;
  final String source;
  final String sourcePath;
  final String trustStatus;
  final int timeoutSec;
  final bool isAsync;
  final String? targetSummary;
  final String? matcher;
  final String? statusMessage;
}

@immutable
final class HookErrorSummaryModel {
  const HookErrorSummaryModel({required this.path, required this.message});

  final String path;
  final String message;
}

@immutable
final class WorkspaceHooksEntrySummary {
  WorkspaceHooksEntrySummary({
    required this.cwd,
    List<HookSummaryModel> hooks = const [],
    List<HookErrorSummaryModel> errors = const [],
    List<String> warnings = const [],
  }) : hooks = List<HookSummaryModel>.unmodifiable(
         hooks.take(maxHooksPerWorkspace),
       ),
       errors = List<HookErrorSummaryModel>.unmodifiable(
         errors.take(maxHookDiagnosticsPerWorkspace),
       ),
       warnings = List<String>.unmodifiable(
         warnings.take(maxHookDiagnosticsPerWorkspace),
       );

  final String cwd;
  final List<HookSummaryModel> hooks;
  final List<HookErrorSummaryModel> errors;
  final List<String> warnings;
}

@immutable
final class HooksDiagnosticsSnapshot {
  HooksDiagnosticsSnapshot({
    required List<WorkspaceHooksEntrySummary> entries,
    required this.totalHookCount,
    required this.totalErrorCount,
    required this.totalWarningCount,
  }) : entries = List<WorkspaceHooksEntrySummary>.unmodifiable(
         entries.take(maxHookEntries),
       );

  final List<WorkspaceHooksEntrySummary> entries;
  final int totalHookCount;
  final int totalErrorCount;
  final int totalWarningCount;
}

sealed class RuntimeDiagnosticsEvent {
  const RuntimeDiagnosticsEvent();
}

final class AccountUpdatedDiagnosticsEvent extends RuntimeDiagnosticsEvent {
  const AccountUpdatedDiagnosticsEvent({this.authMode, this.planType});

  final String? authMode;
  final String? planType;
}

final class AccountRateLimitsUpdatedDiagnosticsEvent
    extends RuntimeDiagnosticsEvent {
  const AccountRateLimitsUpdatedDiagnosticsEvent({required this.rateLimits});

  final RateLimitBucketSnapshot rateLimits;
}
