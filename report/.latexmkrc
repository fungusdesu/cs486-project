$pdf_mode = 1;

$aux_dir = '.aux';
$out_dir = '.';

$biber = "biber --input-directory $aux_dir %O %S";

$cmd_spec = "-synctex=1 -interaction=batchmode -file-line-error -output-directory=$aux_dir %O %S";
$pdflatex = "pdflatex $cmd_spec";

$pdf_previewer = 'start evince';
