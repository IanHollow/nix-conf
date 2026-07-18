{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  findutils,
  gnused,
}:

let
  pname = "anthropic-skills";
  source = import ./source.nix;
in
stdenvNoCC.mkDerivation (_finalAttrs: {
  inherit pname;
  inherit (source) version;

  src = fetchFromGitHub source.src;
  nativeBuildInputs = [
    findutils
    gnused
  ];
  strictDeps = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    skill_root="$out/share/agent-skills"
    mkdir -p "$skill_root"
    for source_skill in "$src"/skills/*; do
      test -f "$source_skill/SKILL.md" || continue
      skill_name="$(basename "$source_skill")"
      target_name="anthropic-$skill_name"
      target_skill="$TMPDIR/$target_name"
      cp -R --no-preserve=ownership "$source_skill" "$target_skill"
      chmod -R u+w "$target_skill"
      sed -i "0,/^name: /s//name: $target_name/" "$target_skill/SKILL.md"
      cp -R --no-preserve=ownership "$target_skill" "$skill_root/$target_name"
    done

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    test "$(find "$out/share/agent-skills" -mindepth 1 -maxdepth 1 -type d | wc -l)" = 17
    while IFS= read -r skill_file; do
      grep -q '^---$' "$skill_file"
      grep -q "^name: anthropic-" "$skill_file"
    done < <(find "$out/share/agent-skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | sort)

    runHook postInstallCheck
  '';

  passthru.updateScript = [ ./update.py ];

  meta = {
    description = "Anthropic Agent Skills catalog";
    homepage = "https://github.com/anthropics/skills";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
})
