{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

let
  pname = "remindctl";
  source = import ./source.nix;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname;
  inherit (source) version;

  src = fetchurl source.src;
  agentSkillSource = fetchurl source.skill;

  nativeBuildInputs = [ unzip ];
  sourceRoot = ".";
  strictDeps = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 remindctl "$out/bin/${pname}"
    install -Dm644 "$agentSkillSource" "$out/share/agent-skills/apple-reminders/SKILL.md"

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test "$("$out/bin/${pname}" --version)" = "${finalAttrs.version}"
    grep -q '^name: apple-reminders$' "$out/share/agent-skills/apple-reminders/SKILL.md"

    runHook postInstallCheck
  '';

  passthru = {
    agentSkill = "${finalAttrs.finalPackage}/share/agent-skills/apple-reminders";
    updateScript = [ ./update.py ];
  };

  meta = {
    description = "Fast command-line access to Apple Reminders";
    homepage = "https://remindctl.sh";
    downloadPage = "https://github.com/openclaw/remindctl/releases";
    license = lib.licenses.mit;
    mainProgram = pname;
    platforms = [ "aarch64-darwin" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
})
