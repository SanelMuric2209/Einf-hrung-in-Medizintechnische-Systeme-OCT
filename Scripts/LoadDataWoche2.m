%% Initialisierung
clear; close all; clc; 

%%1. Alle 25 Volumen des Grids laden
sizeX = 250;
sizeY = 250;
sizeZ = 512;
all_volumes = cell(5, 5);

% Define the path to your data folder
data_dir = fullfile('data', '2_Circle_0001');

fprintf('Starte Ladevorgang für das 5x5 Grid aus Ordner: %s...\n', data_dir);

for r = 1:5
    for c = 1:5
        % Generate the full path including the folder and filename
        filename = fullfile(data_dir, sprintf('Vol_circle_%d_%d.h5', r, c));
        
        if exist(filename, 'file')
            fprintf('Lade Datei: %s...\n', filename);
            info = h5info(filename);
            name = info.Datasets.Name;
            data = h5read(filename, ['/' name]);
            all_volumes{r, c} = reshape(data, sizeX, sizeY, sizeZ);
        else
            warning('Datei %s wurde nicht gefunden!', filename);
        end
    end
end
fprintf('Ladevorgang abgeschlossen.\n\n');

%% 5. Zusammensetzen aller 25 Kacheln zu einem großen Gesamtvolumen
% Jedes Einzelvolumen hat die Größe 250 x 250 x 512 Pixel
large_sizeX = 5 * sizeX; % Vertikale Gesamtlänge (5 Zeilen * 250 px = 1250 px)
large_sizeY = 5 * sizeY; % Horizontale Gesamtlänge (5 Spalten * 250 px = 1250 px)
large_sizeZ = sizeZ;     % 512 Pixel Tiefenauflösung

% Vorallokation des großen vordefinierten Speicherraums
% Dimension 1 = Vertikal (Zeilen), Dimension 2 = Horizontal (Spalten), Dimension 3 = Tiefe
large_volume = zeros(large_sizeX, large_sizeY, large_sizeZ);

fprintf('Zusammensetzen des 5x5 Grids zu einem Gesamtvolumen...\n');
for r = 1:5
    for c = 1:5
        if ~isempty(all_volumes{r, c})
            % 1. Vertikale Richtung (Zeilen): Reihenfolge UMKEHREN!
            % Kachel r=1 mappt nun auf die untersten Pixel (1001:1250)
            % Kachel r=5 mappt nun auf die obersten Pixel (1:250)
            startRow = (5 - r) * sizeX + 1;
            endRow = (6 - r) * sizeX;
            
            % 2. Horizontale Richtung (Spalten): Bleibt unverändert (links nach rechts)
            % Kachel c=1 mappt auf Pixel 1:250, c=2 auf 251:500, etc.
            startCol = (c - 1) * sizeY + 1;
            endCol = c * sizeY;
            
            % Blockweises Einfügen des 3D-Teilvolumens
            large_volume(startRow:endRow, startCol:endCol, :) = all_volumes{r, c};
        end
    end
end
fprintf('Gesamtvolumen erfolgreich erstellt.\n\n');

%% 6. Großer C-Scan (Maximum Intensity Projection - MIP)
large_c_scan_mip = max(large_volume, [], 3);

figure('Name', 'Großer C-Scan (Gesamt-MIP)', 'NumberTitle', 'off');
imagesc(large_c_scan_mip); 
colormap gray;
title('Großer C-Scan: Maximum Intensity Projection (Gesamt-Grid)');
xlabel('Horizontale Position (Spalten in Pixeln)');
ylabel('Vertikale Position (Zeilen in Pixeln)');
colorbar;
axis image; 
%% 7. Großer B-Scan (Kontinuierlicher Querschnitt)
mid_Row = round(large_sizeX / 2);
large_b_scan_horz = squeeze(large_volume(mid_Row, :, :));

figure('Name', 'Großer B-Scan (Horizontaler Gesamtschnitt)', 'NumberTitle', 'off');
imagesc(large_b_scan_horz'); 
colormap gray;
title(sprintf('Großer B-Scan: Horizontaler Schnitt durch alle Spalten bei Zeile Y = %d px', mid_Row));
xlabel('Horizontale Position über das 5x5 Grid (Pixel)');
ylabel('Tiefe Z (Pixel)');
colorbar;

% --- Variante B: Vertikaler Schnitt durch alle 5 Zeilen-Kacheln ---
mid_Col = round(large_sizeY / 2);
large_b_scan_vert = squeeze(large_volume(:, mid_Col, :));

figure('Name', 'Großer B-Scan (Vertikaler Gesamtschnitt)', 'NumberTitle', 'off');
imagesc(large_b_scan_vert'); 
colormap gray;
title(sprintf('Großer B-Scan: Vertikaler Schnitt durch alle Zeilen bei Spalte X = %d px', mid_Col));
xlabel('Vertikale Position über das 5x5 Grid (Pixel)');
ylabel('Tiefe Z (Pixel)');
colorbar;