{buildGoModule}:
buildGoModule {
  pname = "gpiosimtest";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-wufUG34GPZLdcuhVls06o3uiVf0wYUVjFQOdbYbZ5pg=";
  tags = ["nomsgpack"];
  meta = {
    description = "GPIO chip simulation API";
    homepage = "https://github.com/LowPowerLab/ATX-Raspi";
    mainProgram = "gpiosimtest";
  };
}
