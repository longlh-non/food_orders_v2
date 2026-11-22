/// The one rule for menu picture file names, shared by `GET /menu` (which
/// only returns a stored name that passes it) and `GET /images/{file}`
/// (which only serves a file whose name passes it).
///
/// Lowercase letters, digits and `-`, starting with a letter or digit, at
/// most 64 characters before the extension, and one of four extensions.
/// So a name can never contain `/`, `..`, `%`, spaces or capitals.
final menuImageName = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}\.(jpg|jpeg|png|webp)$');

/// True when [name] is an acceptable picture file name.
bool isValidImageName(String name) => menuImageName.hasMatch(name);
