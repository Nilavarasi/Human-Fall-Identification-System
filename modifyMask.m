function fgClose = modifyMask(fgMask,strelType,strelSize)

%finding foregorund mask, filling holes and closing gaps
%  fills holes in the input binary image BW
%  performs a flood-fill operation on background pixels of the input binary image BW, 
% starting from the points specified in locations.
fgFill = imfill(fgMask,'holes');


% performs morphological closing on the grayscale or binary image I ,
%  using the structuring element SE . 
fgClose = imclose(fgFill,strel(strelType,strelSize));

end