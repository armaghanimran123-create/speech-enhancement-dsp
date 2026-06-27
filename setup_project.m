% setup_project.m
clear; close all; clc;

projectRoot = pwd;   % if running inside project folder on MATLAB Online
addpath(genpath(projectRoot));

dataDir    = fullfile(projectRoot,'data');
figDir     = fullfile(projectRoot,'figures');
resultsDir = fullfile(projectRoot,'results');

if ~exist(dataDir,'dir')
    mkdir(dataDir);
end
if ~exist(figDir,'dir')
    mkdir(figDir);
end
if ~exist(resultsDir,'dir')
    mkdir(resultsDir);
end
