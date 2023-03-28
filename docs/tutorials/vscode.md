# Juvix VSCode extension tutorial

To install the Juvix VSCode extension, click on the "Extensions" button
in the left panel and search for the "Juvix" extension by Heliax.

Once you've installed the Juvix extension, you can open a Juvix file.
For example, create a `Hello.juvix` file with the following content.

```juvix
module Hello;

open import Stdlib.Prelude;

main : IO;
main := printStringLn "Hello world!";

end;
```

Syntax should be automatically highlighted for any file with `.juvix`
extension. You can jump to the definition of an identifier by pressing
F12 or control-clicking it. To apply the Juvix code formatter to the
current file, use Shift+Ctrl+I.

In the top right-hand corner of the editor window you should see several
buttons. Hover the mouse pointer over a button to see its description.
The functions of the buttons are as follows.

- Load file in REPL (Shift+Alt+R). Launches the Juvix REPL in a
  separate window and loads the current file into it. You can then
  evaluate any definition from the loaded file.
- Typecheck (Shift+Alt+T). Type-checks the current file.
- Compile (Shift+Alt+C). Compiles the current file. The resulting
  native executable will be left in the directory of the file.
- Run (Shift+Alt+X). Compiles and runs the current file. The output of
  the executable run is displayed in a separate window.
- Html preview. Generates HTML documentation for the current file and
  displays it in a separate window.