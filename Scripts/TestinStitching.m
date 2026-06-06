%% Initialisierung
clear; close all; clc; 

%% 1. Alle 25 Volumen des Grids laden
sizeX = 250;
sizeY = 250;
sizeZ = 512;

all_volumes = cell(5, 5);
fprintf('Starte Ladevorgang für das 5x5 Grid...\n');

for r = 1:5
    for c = 1:5
        filename = sprintf('Vol_circle_%d_%d.h5', r, c);
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

%% 2. Inkrementelles Stitching über das gesamte 5x5 Grid
% Speicher für globale X, Y und Z-Verschiebungen relativ zu (1,1)
T_global = zeros(5, 5, 3); 
T_global(1, 1, :) = [0, 0, 0]; % Anchor bei (1,1) ist [0, 0, 0]

fprintf('Berechne globale Translationen für alle 25 Volumen...\n');

for r = 1:5
    for c = 1:5
        % Startpunkt überspringen, da dieser als Referenz [0,0,0] dient
        if r == 1 && c == 1
            continue;
        end
        
        % Bestimmen, mit welchem Nachbarn wir vergleichen:
        if c == 1
            % Am Zeilenanfang vergleichen wir vertikal nach oben
            fixed_vol = all_volumes{r-1, 1};
            moving_vol = all_volumes{r, 1};
            prev_row = r-1; prev_col = 1;
        else
            % Innerhalb der Zeile vergleichen wir horizontal nach links
            fixed_vol = all_volumes{r, c-1};
            moving_vol = all_volumes{r, c};
            prev_row = r; prev_col = c-1;
        end
        
        % Falls Daten fehlen, überspringen
        if isempty(fixed_vol) || isempty(moving_vol)
            continue;
        end
        
        % =========================================================
        % SCHRITT 1: X/Y-Registrierung mit 2D MIPs
        % =========================================================
        fixed_mip  = max(fixed_vol, [], 3);
        moving_mip = max(moving_vol, [], 3);
        
        tform_rel = imregcorr(moving_mip, fixed_mip, 'translation');
        if isa(tform_rel, 'affine2d') || isa(tform_rel, 'rigidtform2d')
            tx_rel = tform_rel.T(3,1);
            ty_rel = tform_rel.T(3,2);
        else
            tx_rel = tform_rel.Translation(1);
            ty_rel = tform_rel.Translation(2);
        end
        
        % =========================================================
        % SCHRITT 2: Z-Registrierung (Oberflächen-Topographie)
        % =========================================================
        % Wir berechnen die X/Y-Überlappung wie zuvor
        tx_round = round(tx_rel);
        ty_round = round(ty_rel);
        
        x_fixed_idx  = max(1, 1 + tx_round) : min(sizeX, sizeX + tx_round);
        x_moving_idx = max(1, 1 - tx_round) : min(sizeX, sizeX - tx_round);
        
        y_fixed_idx  = max(1, 1 + ty_round) : min(sizeY, sizeY + ty_round);
        y_moving_idx = max(1, 1 - ty_round) : min(sizeY, sizeY - ty_round);
        
        if ~isempty(x_fixed_idx) && ~isempty(y_fixed_idx)
            
            % 1. Höhenprofil (Topographie) der gesamten Volumen berechnen.
            % max(..., [], 3) gibt uns nicht nur die Helligkeit, sondern 
            % als zweiten Rückgabewert auch den Z-Index (die Höhe) des stärksten Signals!
            [~, z_surf_fixed]  = max(fixed_vol, [], 3);
            [~, z_surf_moving] = max(moving_vol, [], 3);
            
            % 2. Höhenkarten exakt auf den Überlappungsbereich zuschneiden
            surf_overlap_fixed  = z_surf_fixed(y_fixed_idx, x_fixed_idx);
            surf_overlap_moving = z_surf_moving(y_moving_idx, x_moving_idx);
            
            % 3. Z-Verschiebung berechnen. 
            % Wir ziehen die Höhen voneinander ab. Der 'median' ignoriert dabei 
            % automatisch eventuelle Rausch-Spitzen und gibt uns den sauberen Offset.
            height_diff = surf_overlap_fixed - surf_overlap_moving;
            tz_rel = round(median(height_diff(:)));
            
        else
            tz_rel = 0; % Falls kein Überlapp
        end
        % =========================================================
        % SCHRITT 3: Globale Koordinaten akkumulieren
        % =========================================================
        T_global(r, c, 1) = T_global(prev_row, prev_col, 1) + tx_rel;
        T_global(r, c, 2) = T_global(prev_row, prev_col, 2) + ty_rel;
        T_global(r, c, 3) = T_global(prev_row, prev_col, 3) + tz_rel;
        
    end
end
fprintf('Globale Verschiebungen erfolgreich berechnet.\n\n');

%% 3. Ausdehnung der globalen 3D-Leinwand (Canvas) berechnen
x_mins = zeros(5,5); x_maxs = zeros(5,5);
y_mins = zeros(5,5); y_maxs = zeros(5,5);
z_mins = zeros(5,5); z_maxs = zeros(5,5);

for r = 1:5
    for c = 1:5
        if ~isempty(all_volumes{r,c})
            tx = T_global(r, c, 1);
            ty = T_global(r, c, 2);
            tz = T_global(r, c, 3);
            
            x_mins(r,c) = 0.5 + tx;
            x_maxs(r,c) = sizeX + 0.5 + tx;
            y_mins(r,c) = 0.5 + ty;
            y_maxs(r,c) = sizeY + 0.5 + ty;
            z_mins(r,c) = 0.5 + tz;
            z_maxs(r,c) = sizeZ + 0.5 + tz;
        end
    end
end

% Grenzen der großen gemeinsamen 3D-Leinwand bestimmen
global_X_limits = [min(x_mins(x_mins ~= 0)), max(x_maxs(x_maxs ~= 0))];
global_Y_limits = [min(y_mins(y_mins ~= 0)), max(y_maxs(y_maxs ~= 0))];
global_Z_limits = [min(z_mins(z_mins ~= 0)), max(z_maxs(z_maxs ~= 0))];

canvas_width  = round(global_X_limits(2) - global_X_limits(1));
canvas_height = round(global_Y_limits(2) - global_Y_limits(1));
canvas_depth  = round(global_Z_limits(2) - global_Z_limits(1));

% Globale räumliche 3D-Referenzierung erstellen
R_canvas3D = imref3d([canvas_height, canvas_width, canvas_depth], ...
    global_X_limits, global_Y_limits, global_Z_limits);

%% 4. Volumen in den 3D-Raum projizieren und verschmelzen
fprintf('Erstelle zusammengesetztes 3D-Volumen (kann etwas dauern)...\n');

% TIPP: Um Arbeitsspeicher zu sparen, initialisieren wir als 'single'
stitched_volume = zeros(canvas_height, canvas_width, canvas_depth, 'single'); 

for r = 1:5
    for c = 1:5
        if ~isempty(all_volumes{r,c})
            % Umwandeln in single für weniger Speicherverbrauch
            current_vol = single(all_volumes{r, c}); 
            
            % 3D-Transformation für dieses Grid-Element definieren
            tx = T_global(r, c, 1);
            ty = T_global(r, c, 2);
            tz = T_global(r, c, 3);
            
            tform_global3D = transltform3d(tx, ty, tz); 
            
            % 3D-Volumen in die globale Leinwand transformieren
            warped_vol = imwarp(current_vol, tform_global3D, 'OutputView', R_canvas3D);
            
            % Volumen verschmelzen (Maximum-Intensität bei Überlappungen)
            stitched_volume = max(stitched_volume, warped_vol);
        end
    end
end
fprintf('3D-Stitching abgeschlossen.\n\n');

%%
% Möglichkeit B: Echte 3D-Darstellung (Volume Rendering)
figure('Name', 'Echte 3D Visualisierung');
volumeViewer(stitched_volume);