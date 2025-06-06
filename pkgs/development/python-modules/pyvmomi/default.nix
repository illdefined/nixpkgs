{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  lxml,
  requests,
  six,
  pyopenssl,
  pythonOlder,
}:

buildPythonPackage rec {
  pname = "pyvmomi";
  version = "8.0.3.0.1";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "vmware";
    repo = "pyvmomi";
    tag = "v${version}";
    hash = "sha256-wJe45r9fWNkg8oWJZ47bcqoWzOvxpO4soV2SU4N0tb0=";
  };

  propagatedBuildInputs = [
    requests
    six
  ];

  optional-dependencies = {
    sso = [
      lxml
      pyopenssl
    ];
  };

  # Requires old version of vcrpy
  doCheck = false;

  pythonImportsCheck = [
    "pyVim"
    "pyVmomi"
  ];

  meta = with lib; {
    description = "Python SDK for the VMware vSphere API that allows you to manage ESX, ESXi, and vCenter";
    homepage = "https://github.com/vmware/pyvmomi";
    changelog = "https://github.com/vmware/pyvmomi/releases/tag/v${version}";
    license = licenses.asl20;
    maintainers = [ ];
  };
}
