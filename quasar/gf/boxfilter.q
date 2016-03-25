import "system.q"

function imDst = boxfilter(imSrc, r)
    %   BOXFILTER   O(1) time box filtering using cumulative sum
    %
    %   - Definition imDst(x, y)=sum(sum(imSrc(x-r:x+r,y-r:y+r)));
    %   - Running time independent of r; 
    %   - Equivalent to the function: colfilt(imSrc, [2*r+1, 2*r+1], 'sliding', @sum);
    %   - But much faster.
    %
    %    Coding translated from Matlab source available in http://research.microsoft.com/en-us/um/people/kahe/eccv10/
    %    Author: Gonzalo Luzardo

    sz = size(imSrc);
    imDst = zeros(size(imSrc));
    hei = sz[0];
    wid = sz[1];
    if (size(sz)[1]==2)
        ch=1;
    else
        ch = sz[2];
    endif
    
    imCum = zeros(size(imSrc));
    
    %cumulative sum over Y axis 
    for c=0..ch-1
        imCum[:,:,c] = cumsum(imSrc[:,:,c]);
    end
    
    %difference over Y axis
    imDst[1-1..r+1-1,:,:] = imCum[1+r-1..2*r+1-1,:,:];
    imDst[r+2-1..hei-r-1,:,:] = imCum[2*r+2-1..hei-1,:,:] - imCum[1-1..hei-2*r-1-1,:,:];
    imDst[hei-r+1-1..hei-1,:,:] = repmat(imCum[hei-1,:,:], [r, 1]) - imCum[hei-2*r-1..hei-r-1-1,:,:];
     
    %cumulative sum over X axis
    for c=0..ch-1
        imCum[:,:,c] = cumsum(imDst[:,:,c]);
    end
    
    %difference over Y axis
    imDst[:,1-1..r+1-1,:] = imCum[:, 1+r-1..2*r+1-1,:];
    imDst[:,r+2-1..wid-r-1,:] = imCum[:,2*r+2-1..wid-1,:] - imCum[:,1-1..wid-2*r-1-1,:];
    imDst[:,wid-r+1-1..wid-1,:] = repmat(imCum[:, wid-1,:], [1, r]) - imCum[:, wid-2*r-1..wid-r-1-1,:];
    
end

