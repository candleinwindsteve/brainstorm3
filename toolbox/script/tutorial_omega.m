function tutorial_omega(tutorial_dir)
% TUTORIAL_OMEGA: Script that reproduces the results of the online tutorial "Resting state and OMEGA database".
%
% CORRESPONDING ONLINE TUTORIALS:
%     http://neuroimage.usc.edu/brainstorm/Tutorials/RestingOmega
%
% INPUTS: 
%     tutorial_dir: Directory where the sample_omega.zip file has been unzipped

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2017 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Author: Francois Tadel, 2016


%% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
BidsDir = fullfile(tutorial_dir, 'sample_omega');
% Check if the folder contains the required files
if ~file_exist(BidsDir)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_omega.zip.']);
end


%% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialOmega';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% % Delete existing protocol
% gui_brainstorm('DeleteProtocol', ProtocolName);
% % Create new protocol
% gui_brainstorm('CreateProtocol', ProtocolName, 0, 1);
% Start a new report
bst_report('Start');


%% ===== IMPORT BIDS DATASET =====
% Process: Import BIDS dataset
sFilesRaw = bst_process('CallProcess', 'process_import_bids', [], [], ...
    'bidsdir',      {BidsDir, 'BIDS'}, ...
    'nvertices',    15000, ...
    'channelalign', 1);

% Process: Convert to continuous (CTF): Continuous
sFilesRaw = bst_process('CallProcess', 'process_ctf_convert', sFilesRaw, [], ...
    'rectype', 2);  % Continuous


%% ===== PRE-PROCESSING =====
% % Process: Power spectrum density (Welch)
% sFilesPsdBefore = bst_process('CallProcess', 'process_psd', sFilesRaw, [], ...
%     'timewindow',  [], ...
%     'win_length',  4, ...
%     'win_overlap', 50, ...
%     'sensortypes', 'MEG, EEG', ...
%     'edit',        struct(...
%          'Comment',         'Power', ...
%          'TimeBands',       [], ...
%          'Freqs',           [], ...
%          'ClusterFuncTime', 'none', ...
%          'Measure',         'power', ...
%          'Output',          'all', ...
%          'SaveKernel',      0));

% Process: Notch filter: 60Hz 120Hz 180Hz 240Hz 300Hz
sFilesNotch = bst_process('CallProcess', 'process_notch', sFilesRaw, [], ...
    'freqlist',    [60, 120, 180, 240, 300], ...
    'sensortypes', 'MEG, EEG', ...
    'read_all',    1);

% Process: High-pass:0.3Hz
sFilesBand = bst_process('CallProcess', 'process_bandpass', sFilesNotch, [], ...
    'sensortypes', 'MEG, EEG', ...
    'highpass',    0.3, ...
    'lowpass',     0, ...
    'attenuation', 'strict', ...  % 60dB
    'mirror',      0, ...
    'useold',      0, ...
    'read_all',    1);

% Process: Power spectrum density (Welch)
sFilesPsdAfter = bst_process('CallProcess', 'process_psd', sFilesBand, [], ...
    'timewindow',  [0 100], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'sensortypes', 'MEG, EEG', ...
    'edit',        struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));
     
% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFilesPsdAfter, [], ...
    'target',         10, ...  % Frequency spectrum
    'modality',       1);      % MEG (All)

% Process: Delete folders
bst_process('CallProcess', 'process_delete', [sFilesRaw, sFilesNotch], [], ...
    'target', 2);  % Delete folders


%% ===== ARTIFACT CLEANING =====
% Process: Select data files in: */*
sFilesBand = bst_process('CallProcess', 'process_select_files_data', [], [], ...
    'subjectname', 'All');

% Process: Select file names with tag: task-rest
sFilesRest = bst_process('CallProcess', 'process_select_tag', sFilesBand, [], ...
    'tag',    'task-rest', ...
    'search', 1, ...  % Search the file names
    'select', 1);  % Select only the files with the tag

% Process: Detect heartbeats
bst_process('CallProcess', 'process_evt_detect_ecg', sFilesRest, [], ...
    'channelname', 'ECG', ...
    'timewindow',  [], ...
    'eventname',   'cardiac');

% Process: SSP ECG: cardiac
bst_process('CallProcess', 'process_ssp_ecg', sFilesRest, [], ...
    'eventname',   'cardiac', ...
    'sensortypes', 'MEG', ...
    'usessp',      1, ...
    'select',      1);

% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesRest, [], ...
    'target',         1, ...  % Sensors/MRI registration
    'modality',       1, ...  % MEG (All)
    'orient',         1);  % left

% Process: Snapshot: SSP projectors
bst_process('CallProcess', 'process_snapshot', sFilesRest, [], ...
    'target',         2, ...  % SSP projectors
    'modality',       1);     % MEG (All)


%% ===== SOURCE ESTIMATION =====
% Process: Select file names with tag: task-rest
sFilesNoise = bst_process('CallProcess', 'process_select_tag', sFilesBand, [], ...
    'tag',    'task-noise', ...
    'search', 1, ...  % Search the file names
    'select', 1);  % Select only the files with the tag

% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesNoise, [], ...
    'baseline',       [], ...
    'sensortypes',    'MEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       1, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesRest, [], ...
    'sourcespace', 1, ...  % Cortex surface
    'meg',         3);     % Overlapping spheres

% Process: Compute sources [2016]
sSrcRest = bst_process('CallProcess', 'process_inverse_2016', sFilesRest, [], ...
    'output',  2, ...  % Kernel only: one per file
    'inverse', struct(...
         'Comment',        'dSPM: MEG', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'dspm', ...
         'SourceOrient',   {{'fixed'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG'}}));


%% ===== POWER MAPS =====
% Process: Power spectrum density (Welch)
sSrcPsd = bst_process('CallProcess', 'process_psd', sSrcRest, [], ...
    'timewindow',  [0, 100], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'clusters',    {}, ...
    'scoutfunc',   1, ...  % Mean
    'edit',        struct(...
         'Comment',         'Power,FreqBands', ...
         'TimeBands',       [], ...
         'Freqs',           {{'delta', '2, 4', 'mean'; 'theta', '5, 7', 'mean'; 'alpha', '8, 12', 'mean'; 'beta', '15, 29', 'mean'; 'gamma1', '30, 59', 'mean'; 'gamma2', '60, 90', 'mean'}}, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));

% Process: Spectrum normalization
sSrcPsdNorm = bst_process('CallProcess', 'process_tf_norm', sSrcPsd, [], ...
    'normalize', 'relative', ...  % Relative power (divide by total power)
    'overwrite', 0);

% Process: Project on default anatomy: surface
sSrcPsdProj = bst_process('CallProcess', 'process_project_sources', sSrcPsdNorm, [], ...
    'headmodeltype', 'surface');  % Cortex surface

% Process: Spatial smoothing (3.00)
sSrcPsdProj = bst_process('CallProcess', 'process_ssmooth_surfstat', sSrcPsdProj, [], ...
    'fwhm',      3, ...
    'overwrite', 1);

% Process: Average: Everything
sSrcPsdAvg = bst_process('CallProcess', 'process_average', sSrcPsdProj, [], ...
    'avgtype',   1, ...  % Everything
    'avg_func',  1, ...  % Arithmetic average:  mean(x)
    'weighted',  0, ...
    'matchrows', 0, ...
    'iszerobad', 0);

% Screen capture of final result
hFig = view_surface_data([], sSrcPsdAvg.FileName);
set(hFig, 'Position', [200 200 200 200]);
hFigContact = view_contactsheet(hFig, 'freq', 'fig');
bst_report('Snapshot', hFigContact, sSrcPsdAvg.FileName, 'Power');
close([hFig, hFigContact]);

% Save and display report
ReportFile = bst_report('Save', []);
bst_report('Open', ReportFile);




