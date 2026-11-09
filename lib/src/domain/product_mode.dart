/// Internal product-policy identifiers for compatibility research. A policy
/// does not identify a connected backend or grant execution authority.
enum ProductMode {
  codex,
  work,
  chat;

  String get id => switch (this) {
    ProductMode.codex => 'codex',
    ProductMode.work => 'work',
    ProductMode.chat => 'chat',
  };

  /// Default client-side presentation detail policy for this product mode.
  ///
  /// Strictly enforced as a pure UI projection filter; never injects prompts.
  PresentationDetailPolicy get defaultDetailPolicy => switch (this) {
    ProductMode.codex => PresentationDetailPolicy.commands,
    ProductMode.work => PresentationDetailPolicy.prose,
    ProductMode.chat => PresentationDetailPolicy.prose,
  };

  BackendCapabilities get capabilities =>
      BackendCapabilities.forProductMode(this);
}

enum PresentationDetailPolicy { prose, commands, execution }

class BackendCapabilities {
  const BackendCapabilities({
    required this.supportsThreadRename,
    required this.supportsThreadArchive,
    required this.supportsThreadFork,
    required this.supportsThreadRevert,
    required this.supportsThreadCompact,
    required this.supportsTurnSteer,
    required this.supportsCommandExecution,
    required this.supportsInteractiveApprovals,
    required this.supportsGitDiff,
    required this.supportsStructuredAttachments,
    required this.supportsSkillsAndMcp,
    required this.supportsOfficialRemoteControlHost,
    this.supportsSandboxConfiguration = true,
    this.supportsWorkingDirectorySelection = true,
    this.supportsBranchNavigation = true,
    this.supportsInConversationSearch = true,
  });

  const BackendCapabilities.stockCodexLocal()
    : supportsThreadRename = true,
      supportsThreadArchive = true,
      supportsThreadFork = true,
      supportsThreadRevert = true,
      supportsThreadCompact = true,
      supportsTurnSteer = true,
      supportsCommandExecution = true,
      supportsInteractiveApprovals = true,
      supportsGitDiff = true,
      supportsStructuredAttachments = true,
      supportsSkillsAndMcp = true,
      supportsOfficialRemoteControlHost = true,
      supportsSandboxConfiguration = true,
      supportsWorkingDirectorySelection = true,
      supportsBranchNavigation = true,
      supportsInConversationSearch = true;

  const BackendCapabilities.workModeLocal()
    : supportsThreadRename = true,
      supportsThreadArchive = true,
      supportsThreadFork = true,
      supportsThreadRevert = true,
      supportsThreadCompact = true,
      supportsTurnSteer = true,
      supportsCommandExecution = true,
      supportsInteractiveApprovals = true,
      supportsGitDiff = true,
      supportsStructuredAttachments = true,
      supportsSkillsAndMcp = true,
      supportsOfficialRemoteControlHost = true,
      supportsSandboxConfiguration = false,
      supportsWorkingDirectorySelection = true,
      supportsBranchNavigation = true,
      supportsInConversationSearch = true;

  const BackendCapabilities.chatModeLocal()
    : supportsThreadRename = true,
      supportsThreadArchive = true,
      supportsThreadFork = true,
      supportsThreadRevert = true,
      supportsThreadCompact = true,
      supportsTurnSteer = true,
      supportsCommandExecution = false,
      supportsInteractiveApprovals = false,
      supportsGitDiff = false,
      supportsStructuredAttachments = true,
      supportsSkillsAndMcp = false,
      supportsOfficialRemoteControlHost = false,
      supportsSandboxConfiguration = false,
      supportsWorkingDirectorySelection = false,
      supportsBranchNavigation = true,
      supportsInConversationSearch = true;

  const BackendCapabilities.directHostRemoteReadOnly()
    : supportsThreadRename = false,
      supportsThreadArchive = false,
      supportsThreadFork = false,
      supportsThreadRevert = false,
      supportsThreadCompact = false,
      supportsTurnSteer = false,
      supportsCommandExecution = false,
      supportsInteractiveApprovals = false,
      supportsGitDiff = false,
      supportsStructuredAttachments = false,
      supportsSkillsAndMcp = false,
      supportsOfficialRemoteControlHost = false,
      supportsSandboxConfiguration = false,
      supportsWorkingDirectorySelection = false,
      supportsBranchNavigation = false,
      supportsInConversationSearch = true;

  const BackendCapabilities.openAiPublicResponses()
    : supportsThreadRename = true,
      supportsThreadArchive = true,
      supportsThreadFork = true,
      supportsThreadRevert = false,
      supportsThreadCompact = false,
      supportsTurnSteer = false,
      supportsCommandExecution = false,
      supportsInteractiveApprovals = false,
      supportsGitDiff = false,
      supportsStructuredAttachments = true,
      supportsSkillsAndMcp = false,
      supportsOfficialRemoteControlHost = false,
      supportsSandboxConfiguration = false,
      supportsWorkingDirectorySelection = false,
      supportsBranchNavigation = true,
      supportsInConversationSearch = true;

  factory BackendCapabilities.forProductMode(ProductMode mode) =>
      switch (mode) {
        ProductMode.codex => const BackendCapabilities.stockCodexLocal(),
        ProductMode.work => const BackendCapabilities.workModeLocal(),
        ProductMode.chat => const BackendCapabilities.chatModeLocal(),
      };

  final bool supportsThreadRename;
  final bool supportsThreadArchive;
  final bool supportsThreadFork;
  final bool supportsThreadRevert;
  final bool supportsThreadCompact;
  final bool supportsTurnSteer;
  final bool supportsCommandExecution;
  final bool supportsInteractiveApprovals;
  final bool supportsGitDiff;
  final bool supportsStructuredAttachments;
  final bool supportsSkillsAndMcp;
  final bool supportsOfficialRemoteControlHost;
  final bool supportsSandboxConfiguration;
  final bool supportsWorkingDirectorySelection;
  final bool supportsBranchNavigation;
  final bool supportsInConversationSearch;
}
