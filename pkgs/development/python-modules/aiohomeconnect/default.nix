{
  lib,
  authlib,
  buildPythonPackage,
  fastapi,
  fetchFromGitHub,
  httpx-sse,
  httpx,
  mashumaro,
  pytest-asyncio,
  pytest-cov-stub,
  pytest-httpx,
  pytestCheckHook,
  pythonOlder,
  setuptools,
  typer,
  uvicorn,
}:

buildPythonPackage rec {
  pname = "aiohomeconnect";
  version = "0.18.1";
  pyproject = true;

  disabled = pythonOlder "3.11";

  src = fetchFromGitHub {
    owner = "MartinHjelmare";
    repo = "aiohomeconnect";
    tag = "v${version}";
    hash = "sha256-Gi6uSImA3R1/7CYbyzg/0j6z/wVFpuEzJNeTCoglhpY=";
  };

  build-system = [ setuptools ];

  dependencies = [
    httpx
    httpx-sse
    mashumaro
  ];

  optional-dependencies = {
    cli = [
      authlib
      fastapi
      typer
      uvicorn
    ];
  };

  nativeCheckInputs = [
    pytest-asyncio
    pytest-cov-stub
    pytest-httpx
    pytestCheckHook
  ]
  ++ lib.flatten (builtins.attrValues optional-dependencies);

  pythonImportsCheck = [ "aiohomeconnect" ];

  meta = {
    description = "asyncio client for the Home Connect API";
    homepage = "https://github.com/MartinHjelmare/aiohomeconnect";
    changelog = "https://github.com/MartinHjelmare/aiohomeconnect/blob/${src.tag}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ fab ];
  };
}
