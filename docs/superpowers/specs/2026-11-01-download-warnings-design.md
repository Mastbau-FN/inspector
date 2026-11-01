# Successful inspection downloads with file warnings

The user wants Gerberpfad 23 v250 Die Zweite to finish downloading successfully despite three server JPGs containing zero bytes. The user needs an actionable list instead of repeatedly pressing an unexplained red reload button.

Use the existing Flutter download workflow. Only a successful HTTP image response explicitly declaring zero bytes is a nonblocking empty-server-file warning. Network failures, unavailable storage, nonempty invalid images and failed documents remain download failures. Preserve original image references and server files so repaired images can be retrieved later.

Keep the green completion check and add a visible, tappable warning count. Its dialog explains offline availability and lists each affected filename and inspection entry. Persist this list locally across navigation/restart and replace it on each subsequent completed photo pass, clearing resolved warnings. Keep warnings out of server inspection payloads.

Approaches: treating every failure as success would conceal real transfer failures; keeping the red retry button fails the user's requested behavior. A narrow typed empty-file condition plus a persistent local warning list provides successful completion and useful diagnostics.

Server investigation is read-only: inspect file sizes, mount/source paths, timestamps and logs, then compare available copies. Do not replace/delete originals or replay pending uploads. An SSH authentication failure requires connection details from the user; application work can continue independently.

Follow-up requested by the user: add a Fertig action beside Erneut prüfen and Schließen. Fertig acknowledges only the displayed file warnings and closes the dialog, leaving an ordinary green check. Remember these acknowledgements locally per inspection and file so repeated downloads do not show the same warnings. New files remain visible, and a file repaired in a successful photo pass must be reported again if a later incident makes it empty. Schließen keeps the pending warnings. Neither action changes server images or image references.
