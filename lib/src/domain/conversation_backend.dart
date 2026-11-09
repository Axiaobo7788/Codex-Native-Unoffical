import 'approval_gateway.dart';
import 'ecosystem_gateway.dart';
import 'history_gateway.dart';
import 'model_gateway.dart';
import 'output_gateway.dart';
import 'product_mode.dart';
import 'thread_gateway.dart';
import 'turn_gateway.dart';
import 'user_input_gateway.dart';

/// Unified domain contract for conversational thread, history, model, and turn
/// operations shared across `ProductMode.codex`, `ProductMode.work`, and
/// `ProductMode.chat`.
abstract interface class ConversationBackend
    implements ModelGateway, ThreadGateway, HistoryGateway, TurnGateway {}

/// Unified domain contract for workspace execution, interactive approvals,
/// spooled command output, and skills/plugins/MCP discovery.
abstract interface class ExecutionBackend
    implements
        ApprovalGateway,
        UserInputGateway,
        OutputGateway,
        EcosystemGateway {}

/// Resolves the effective `BackendCapabilities` by intersecting transport-level
/// backend capabilities with the active `ProductMode` presentation policy.
BackendCapabilities resolveEffectiveCapabilities({
  required ProductMode mode,
  required BackendCapabilities transportCapabilities,
}) {
  final modeCaps = mode.capabilities;
  return BackendCapabilities(
    supportsThreadRename:
        transportCapabilities.supportsThreadRename &&
        modeCaps.supportsThreadRename,
    supportsThreadArchive:
        transportCapabilities.supportsThreadArchive &&
        modeCaps.supportsThreadArchive,
    supportsThreadFork:
        transportCapabilities.supportsThreadFork && modeCaps.supportsThreadFork,
    supportsThreadRevert:
        transportCapabilities.supportsThreadRevert &&
        modeCaps.supportsThreadRevert,
    supportsThreadCompact:
        transportCapabilities.supportsThreadCompact &&
        modeCaps.supportsThreadCompact,
    supportsTurnSteer:
        transportCapabilities.supportsTurnSteer && modeCaps.supportsTurnSteer,
    supportsCommandExecution:
        transportCapabilities.supportsCommandExecution &&
        modeCaps.supportsCommandExecution,
    supportsInteractiveApprovals:
        transportCapabilities.supportsInteractiveApprovals &&
        modeCaps.supportsInteractiveApprovals,
    supportsGitDiff:
        transportCapabilities.supportsGitDiff && modeCaps.supportsGitDiff,
    supportsStructuredAttachments:
        transportCapabilities.supportsStructuredAttachments &&
        modeCaps.supportsStructuredAttachments,
    supportsSkillsAndMcp:
        transportCapabilities.supportsSkillsAndMcp &&
        modeCaps.supportsSkillsAndMcp,
    supportsOfficialRemoteControlHost:
        transportCapabilities.supportsOfficialRemoteControlHost &&
        modeCaps.supportsOfficialRemoteControlHost,
    supportsSandboxConfiguration:
        transportCapabilities.supportsSandboxConfiguration &&
        modeCaps.supportsSandboxConfiguration,
    supportsWorkingDirectorySelection:
        transportCapabilities.supportsWorkingDirectorySelection &&
        modeCaps.supportsWorkingDirectorySelection,
    supportsBranchNavigation:
        transportCapabilities.supportsBranchNavigation &&
        modeCaps.supportsBranchNavigation,
    supportsInConversationSearch:
        transportCapabilities.supportsInConversationSearch &&
        modeCaps.supportsInConversationSearch,
  );
}
