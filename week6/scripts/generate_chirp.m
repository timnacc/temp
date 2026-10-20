% Optional MATLAB equivalent; the Python generator is used for supplied X.txt.
fs = 1000;
t = (0:1999) / fs;
signal = chirp(t, 0, 1, 250, 'linear', 0);
X = uint8(round((signal + 1) * 127.5));
script_dir = fileparts(mfilename('fullpath'));
file = fopen(fullfile(script_dir, '..', 'sim', 'X.txt'), 'w');
assert(file ~= -1, 'Cannot open X.txt');
binary_lines = cellstr(dec2bin(X(:), 8));
fprintf(file, '%s\n', binary_lines{:});
fclose(file);
