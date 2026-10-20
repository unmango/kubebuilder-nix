{ pkgs, kblib }:
let
  scaffold =
    version: hash:
    kblib.mkScaffold pkgs {
      name = "memcached-scaffold-${version}";
      src = ../examples/memcached;
      inherit version hash;
    };
in
{
  example-scaffold-4_15 = scaffold "4.15.0" "sha256-hliELz36Ws9dZSxeRA6z5q+L3LIMSJ7nyNqfkUMjofo=";
  example-scaffold-4_16 = scaffold "4.16.0" "sha256-IVwWqGytTml0YQExf8ShJ0fGgbWCvXFRVSY1VpORUtk=";
}
