enum ProductMode {
  codex,
  work,
  chat;

  String get id => switch (this) {
    ProductMode.codex => 'codex',
    ProductMode.work => 'work',
    ProductMode.chat => 'chat',
  };

  String get label => switch (this) {
    ProductMode.codex => 'Codex',
    ProductMode.work => 'Work',
    ProductMode.chat => 'Chat',
  };

  String get description => switch (this) {
    ProductMode.codex =>
      'Code, terminal commands, diffs, and workspace execution.',
    ProductMode.work =>
      'Everyday tasks with intermediate tool steps collapsed by default.',
    ProductMode.chat => 'Conversational prose and structured attachments.',
  };

  /// Default client-side presentation detail policy for this product mode.
  ///
  /// Strictly enforced as a pure UI projection filter; never injects prompts.
  PresentationDetailPolicy get defaultDetailPolicy => switch (this) {
    ProductMode.codex => PresentationDetailPolicy.commands,
    ProductMode.work => PresentationDetailPolicy.prose,
    ProductMode.chat => PresentationDetailPolicy.prose,
  };
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
      supportsOfficialRemoteControlHost = true;

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
      supportsOfficialRemoteControlHost = false;

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
      supportsOfficialRemoteControlHost = false;

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
}
