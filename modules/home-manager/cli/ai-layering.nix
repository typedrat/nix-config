# Combines the agent-agnostic `cli.ai` settings with one harness's overlay
# (`cli.ai.claude-code`, `cli.ai.opencode`).
{lib}: let
  read = value:
    if lib.isPath value
    then builtins.readFile value
    else value;

  # A lone path passes through untouched so the harness links the file
  # rather than a copy of its text.
  mergeContext = shared: harness:
    if harness == ""
    then shared
    else if shared == ""
    then harness
    else "${read shared}\n\n${read harness}";
in {
  inherit mergeContext;

  mergeHarness = ai: harness: {
    context = mergeContext ai.context harness.context;
    rules = ai.rules // harness.rules;
    skills = ai.skills // harness.skills;
  };
}
