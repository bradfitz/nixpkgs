{ lib
, buildPythonPackage
, fetchPypi
, six
, webencodings
, mock
, pytest-expect
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "html5lib";
  version = "1.1";

  src = fetchPypi {
    inherit pname version;
    sha256 = "b2e5b40261e20f354d198eae92afc10d750afb487ed5e50f9c4eaf07c184146f";
  };

  propagatedBuildInputs = [
    six
    webencodings
  ];

  # latest release not compatible with pytest 6
  doCheck = false;
  checkInputs = [
    mock
    pytest-expect
    pytestCheckHook
  ];

  meta = {
    homepage = "https://github.com/html5lib/html5lib-python";
    downloadPage = "https://github.com/html5lib/html5lib-python/releases";
    description = "HTML parser based on WHAT-WG HTML5 specification";
    longDescription = ''
      html5lib is a pure-python library for parsing HTML. It is designed to
      conform to the WHATWG HTML specification, as is implemented by all
      major web browsers.
    '';
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ domenkozar prikhi ];
  };
}
