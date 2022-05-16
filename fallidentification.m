% Author: Nilavarasi Sivasankaran
% Date: 01-05-2022

function [] = fallidentification()

% reading the FALL video
vid = vision.VideoFileReader("/Users/nilavarasisivasankaran/Documents/MATLAB/Human Fall Identification System/fall.mp4");

% Uncomment the below line for reading the NO FALL video
% vid = vision.VideoFileReader("/Users/nilavarasisivasankaran/Documents/MATLAB/Human Fall Identification System/no fall.avi");


% Uncomment the below line for reading the NO Human video
% vid = vision.VideoFileReader("/Users/nilavarasisivasankaran/Documents/MATLAB/Human Fall Identification System/no human.mp4");


% initializing foreground and blob detectors
% The ForegroundDetector compares a color or grayscale video frame to a background model
% to determine whether individual pixels are part of the background or the foreground. 
% It then computes a foreground mask. By using background subtraction, 
% you can detect foreground objects in an image taken from a stationary camera.
detector = vision.ForegroundDetector(...
    'NumTrainingFrames',10,'NumGaussians',5,...
    'MinimumBackgroundRatio', 0.7,'InitialVariance',0.05,...
    'LearningRate',0.0002);
% To compute statistics for connected regions in a binary image
blob = vision.BlobAnalysis(...
    'CentroidOutputPort', true, 'AreaOutputPort', true, ...
    'BoundingBoxOutputPort', true, ...
    'MinimumBlobAreaSource', 'Property', 'MinimumBlobArea', 500);

%duration of mhi (or) max. value of mhi (or) no of frames taken into acc. for mhi
tmhi = 15;

%strel parameters
strelType = 'square';
strelSize = 5;

%tolerance while find coordinate of y at min. x in counding ellipse
%tolerance for yxmin <= Cy+1 in degrees
noiseYxmin = 3;

%resize Parameter (fraction of input frame)
resizeFactor = 0.25;

%   Fall Detection Parameters
%threshold for detecting high motion
thresMotion = 1.8;
%threshold speed for concluding fall
thSpeed = 2;
%threshold orientation change for concluding fall
thOrChg = 15;
%threshold area change for concluding fall
thAreaChg = 15;
%no of frames that form a fall sequence
noFrFallSeq = 5;

%object that contains possible fall sequences
%object contains ->speed , ->noFrames, ->avgOrChg, ->avgAreaChg
%noFrames - no. of frames that have been taken into acc. till now
posFalls = struct([]);

prevOr = [];

frameNo = 0;
while ~isDone(vid)
    pause(0.0001);
    frame =  step(vid);
    frameNo = frameNo+1;
    %resizing original frame
    %frame = imresize(frame,resizeFactor);
    
    %assigning initial value to motion history image
    if frameNo == 1
        % Query only the length of the first and second dimension of Frame. 
        mhimage = zeros(size(frame,1),size(frame,2));
    end
    
    %detecting foreground mask
    fgMask = step(detector,frame);
    %modifying mask to close gaps and fill holes
    fgClose = modifyMask(fgMask,strelType,strelSize);
    
    %finding largest blob
    [area,centroid,box] = step(blob,fgClose);
    pos = find(area==max(area));
    % Create two axes using the pos and all. 
    % Assign the axes objects to the variables ax1 and ax2, 
    % and plot into the axes.
    box = box(pos,:);
    
    speed = [];orientation = [];area = [];
    if ~isempty(box)
        %fgBBox - the mask after inside bouding box
        %removing cordinates outside bounding box
        fgBBox = maskInsideBBox(fgClose,box);
        [mhimage,speed] = calcSpeed(mhimage,fgBBox,tmhi);
        if speed >= thresMotion
            posFalls = initializeFallObj(posFalls,size(posFalls,2)+1);
        end
        
        filledCannyMask = logical(edge(fgBBox,'Roberts'));
        [xcoord,ycoord] = coordInsideMask(filledCannyMask,box);
        ellipse = fitellipse(xcoord,ycoord);
        if ~isempty(ellipse)
            orientation = calcOrientation(ellipse,noiseYxmin);
            area = pi*ellipse(3)*ellipse(4);
            
            %output
            subplot(1,4,1);
            imshow(frame);
            title(sprintf('Original Video\nFrame no - %d',frameNo),'FontSize',20);
            subplot(1,4,2);
            imshow(fgMask);
            title(sprintf('Human detection\nFrame no - %d',frameNo),'FontSize',20);
            subplot(1,4,3);
            imshow(uint8((mhimage*255)/tmhi));
            title(sprintf('Motion History Image\nSpeed - %f',speed),'FontSize',20);
            subplot(1,4,4);
            imshow(filledCannyMask);
            drawEllipse(ellipse(1),ellipse(2),ellipse(3),ellipse(4),ellipse(5));
            title(sprintf('Shape of body\nOrientation - %f',orientation),'FontSize',20);
        else
            %output
            subplot(1,4,1);
            imshow(frame);
            title(sprintf('Original Video\nFrame no - %d',frameNo),'FontSize',20);
            subplot(1,4,2);
            imshow(fgMask);
            title(sprintf('Human detection\nFrame no - %d',frameNo),'FontSize',20);
            subplot(1,4,3);
            imshow(uint8((mhimage*255)/tmhi));
            title(sprintf('Motion History Image\nSpeed - '),'FontSize',20);
            subplot(1,4,4);
            imshow(filledCannyMask);
            title(sprintf('Shape of body\nOrientation - '));
        end
    else
        %output
        subplot(1,4,1);
        imshow(frame);
        title(sprintf('Original Video\nFrame no - %d',frameNo),'FontSize',20);
        subplot(1,4,2);
        imshow(fgMask);
        title(sprintf('Human detection\nFrame no - %d',frameNo),'FontSize',20);
        subplot(1,4,3);
        imshow(uint8((mhimage*255)/tmhi));
        title(sprintf('Motion History Image\nSpeed - '),'FontSize',20);
        subplot(1,4,4);
        imshow(zeros(size(fgMask)));
        title(sprintf('No body\nOrientation - %f',orientation),'FontSize',20);
    end
    
    %no possible fall sequences
    if isempty(posFalls)
        if ~isempty(orientation) && ~isempty(area)
            prevOr = orientation;
            prevArea = area;
        else
            %do not increment last changed frame number
        end
        continue;
    end
    
    %no object is found in foreground mask
    if isempty(speed) || isempty(orientation) || isempty(area)
        % speed,orientation change, area change have to assigned a certain
        % value
        posFalls = struct([]);
        %do not increment last changed frame number
        continue;
    end
    
    if isempty(prevOr)
        orChg = 0;
        areaChg = 0;
    else
        orChg = findOrChg(orientation,prevOr);
        areaChg = 20;%have to find it.
    end
    prevOr = orientation;
    prevArea = area;
    [fallDetected,posFalls] = updateCheckPosFalls(posFalls,size(posFalls,2),noFrFallSeq,orChg,areaChg,speed,thOrChg,thAreaChg,thSpeed);
    if fallDetected == true   
        
        subplot(1,4,1);
        imshow(frame);
        title(sprintf('Original Video\nFrame no - %d',frameNo),'FontSize',20);
        subplot(1,4,2);
        imshow(fgMask);
        title(sprintf('FALL DETECTED\n Message sent\n'),'FontSize',50);
        %   senig sms to the relative and the hospital
        % backend is done on the PHP
%         s = urlread('http://localhost/sms/sms.php?number=7599222718&text=Your relative XYZ SHYAM is in emergency please reach to his house ASAP');
%         disp(s);
        
        subplot(1,4,3);
        imshow(uint8((mhimage*255)/tmhi));
        title(sprintf('Motion History Image\nSpeed - %f',speed),'FontSize',20);
        subplot(1,4,4);
        imshow(filledCannyMask);
        title(sprintf('Shape of body\nOrientation - %f',orientation),'FontSize',20);
        pause(4);
    end
end

