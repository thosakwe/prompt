import 'dart:io';

/// Prompt the user, and return the first line read.
/// This is the core of [Prompter], and the basis for all other
/// functions.
///
/// A function to [validate] may be passed. If `null`, it defaults
/// to checking if the string is not empty.
///
/// A default value may be given as [defaultsTo]. If present, the [message]
/// will have `' ($defaultsTo)'` append to it.
///
/// If [colon] is `true` (default), then a `:` will be appended to the prompt.
///
/// If [allowMultiline] is `true` (default: `false`), then lines ending in a
/// backslash (`\`) will be interpreted as a signal that another line of
/// input is to come. This is helpful for building REPL's.
String get(String message,
    {bool Function(String) validate,
    String defaultsTo,
    bool colon: true,
    bool allowMultiline: false}) {
  validate ??= (s) => s.trim().isNotEmpty;

  if (defaultsTo != null) {
    var oldValidate = validate;
    validate = (s) => s.trim().isEmpty || oldValidate(s);
  }

  while (true) {
    if (message.isNotEmpty) {
      stdout.write('$message');
      if (defaultsTo != null) stdout.write(' ($defaultsTo)');
      if (colon) stdout.write(':');
      stdout.write(' ');
    }

    var buf = new StringBuffer();

    while (true) {
      var line = stdin.readLineSync().trim();

      if (!line.endsWith('\\')) {
        buf.writeln(line);
        break;
      } else {
        buf.writeln(line.substring(0, line.length - 1));
      }
    }

    var line = buf.toString().trim();

    if (validate(line)) {
      if (defaultsTo != null) return line.isEmpty ? defaultsTo : line;
      return line;
    }
  }
}

/// Presents a yes/no prompt to the user.
///
/// If [appendYesNo] is `true`, then a `(y/n)`, `(Y/n)` or `(y/N)` is
/// appended to the [message], depending on its value.
///
/// [colon] is forwarded to [get].
bool getBool(String message,
    {bool defaultsTo: false, bool appendYesNo: true, bool colon: true}) {
  if (appendYesNo)
    message +=
        defaultsTo == null ? ' (y/n)' : (defaultsTo ? ' (Y/n)' : ' (y/N)');
  var result = get(message, colon: colon, validate: (s) {
    s = s.trim().toLowerCase();
    return (defaultsTo != null && s.isEmpty) ||
        s.startsWith('y') ||
        s.startsWith('n');
  });
  result = result.toLowerCase();

  if (result.isEmpty)
    return defaultsTo;
  else if (result == 'y') return true;
  return false;
}

/// Prompts the user to enter an integer.
///
/// An optional [radix] may be provided.
///
/// [defaultsTo] and [colon] are forwarded to [get].
int getInt(String message, {int defaultsTo, int radix: 10, bool colon: true}) {
  return int.parse(get(
    message,
    defaultsTo: defaultsTo?.toString(),
    colon: colon,
    validate: (s) => int.tryParse(s, radix: radix) != null,
  ));
}

/// Prompts the user to enter a double.
///
/// [defaultsTo] and [colon] are forwarded to [get].
double getDouble(String message, {double defaultsTo, bool colon: true}) {
  return double.parse(get(
    message,
    defaultsTo: defaultsTo?.toString(),
    colon: colon,
    validate: (s) => double.tryParse(s) != null,
  ));
}

/// Displays to the user a list of [options], and returns
/// once one has been chosen.
///
/// Each option will be prefixed with a number, corresponding
/// to its index + `1`.
///
/// A default option may be provided by means of [defaultsTo].
///
/// If [colon] is `true` (default), then a `:`
/// character will also be appended to [message].
///
/// Example:
///
/// ```
/// Choose a color:
///
/// 1) Red
/// 2) Blue
/// 3) Green
/// ```
T choose<T>(String message, Iterable<T> options,
    {T defaultsTo, bool colon: true}) {
  assert(options.isNotEmpty);

  var map = <T, String>{};
  for (var option in options) map[option] = option.toString();

  if (colon) message += ':';

  var b = new StringBuffer();

  b..writeln(message)..writeln();

  for (int i = 0; i < options.length; i++) {
    var key = map.keys.elementAt(i);
    b.write('${i+ 1}) ${map[key]}');
    if (key == defaultsTo) b.write(' [Default - Press Enter]');
    b.writeln();
  }

  b.writeln();

  var line = get(
    b.toString(),
    colon: false,
    validate: (s) {
      if (s.isEmpty) return defaultsTo != null;
      if (map.values.contains(s)) return true;
      int i = int.tryParse(s);
      if (i == null) return false;
      return i >= 1 && i <= options.length;
    },
  );

  if (line.isEmpty) return defaultsTo;
  int i = int.tryParse(line);
  if (i != null) return map.keys.elementAt(i - 1);
  return map.keys.elementAt(map.values.toList(growable: false).indexOf(line));
}

/// Similar to [choose], but opts for a shorthand syntax that fits into one line,
/// rather than a multi-line prompt.
///
/// Acceptable inputs include:
/// * The full value of `toString()` for any one option
/// * The first character (case-insensitive) of `toString()` for an option
///
/// A default option may be provided by means of [defaultsTo].
///
/// If [colon] is `true` (default), a `:` is appended to [message].
T chooseShorthand<T>(String message, Iterable<T> options,
    {T defaultsTo, bool colon: true}) {
  assert(options.isNotEmpty);

  var b = new StringBuffer(message);
  if (colon) b.write(':');
  b.write(' (');
  var firstChars = <String>[], strings = <String>[];
  int i = 0;

  for (var option in options) {
    var str = option.toString();
    if (i++ > 0) b.write('/');

    if (defaultsTo != null) {
      if (defaultsTo == option)
        str = str[0].toUpperCase() + str.substring(1);
      else
        str = str[0].toLowerCase() + str.substring(1);
    }

    b.write(str);
    firstChars.add(str[0].toLowerCase());
    strings.add(str);
  }

  b.write(')');

  T value;

  get(b.toString(), colon: colon, validate: (s) {
    if (s.isEmpty) return (value = defaultsTo) != null;

    if (strings.contains(s)) {
      value = options.elementAt(strings.indexOf(s));
      return true;
    }

    if (firstChars.contains(s[0].toLowerCase())) {
      value = options.elementAt(firstChars.indexOf(s[0].toLowerCase()));
      return true;
    }

    return false;
  });

  return value;
}
