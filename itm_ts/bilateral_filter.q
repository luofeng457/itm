% Bilateral filter
% Author: Simon Donné

import "colortransform.q"

% Function: compute_bilateral_filter
%
% Computes bilateral filter coefficients
%
% Parameters:
% Lab - image in LAB space
% n_width - width of the filter window
% n_height - height of the filter window
% alpha - divisor for the color distance
% beta - divisor for the spatial distance
% eucl_dist - use the euclidian distance (1), or the square of the distance (0)
% normalize - normalize the bilateral filter coefficients over each neighbourhood (1)
%
% :function bf:cube = compute_bilateral_filter(Lab:cube'safe, n_width:int, n_height:int, alpha:scalar, beta:scalar, eucl_dist:scalar, normalize:scalar)

function bf:cube = compute_bilateral_filter(Lab:cube'safe, n_width:int, n_height:int, _
                                                alpha:scalar, beta:scalar, eucl_dist:scalar, normalize:scalar)
    nx2:int = (n_width - 1)/2
    ny2:int = (n_height - 1)/2
    height:int = size(Lab,0)
    width:int  = size(Lab,1)
    
    bf = zeros(height, width, n_width*n_height)
    summ = zeros(height, width)
        
    function [] = __kernel__ fcalcbf(pos:ivec3)
        j = pos[0]
        i = pos[1]
        x = mod(pos[2], n_width)-nx2
        y = floor(pos[2]/n_width)-ny2
        if(j+y < 0 || j+y >= height || i+x < 0 || i+x >= width)
            bf[pos] = 0.0
        else
            diffL = Lab[j+y,i+x,0] - Lab[j, i,0]
            diffa = Lab[j+y,i+x,1] - Lab[j, i,1]
            diffb = Lab[j+y,i+x,2] - Lab[j, i,2]
            cdist = diffL^2 +diffa^2 +diffb^2
            dist  = x^2 + y^2
            bf[pos] = exp(-(cdist/alpha)-(dist/beta))
            summ[j,i] += bf[pos]
        endif
    end  
    function [] = __kernel__ fcalcbfeucl(pos:ivec3)
        j = pos[0]
        i = pos[1]
        x = mod(pos[2], n_width)-nx2
        y = floor(pos[2]/n_width)-ny2
        if(j+y < 0 || j+y >= height || i+x < 0 || i+x >= width)
            bf[pos] = 0.0
        else
            diffL = Lab[j+y,i+x,0] - Lab[j, i,0]
            diffa = Lab[j+y,i+x,1] - Lab[j, i,1]
            diffb = Lab[j+y,i+x,2] - Lab[j, i,2]
            cdist = sqrt(diffL^2 +diffa^2 +diffb^2)
            dist  = sqrt(x^2 + y^2)
            bf[pos] = exp(-(cdist/alpha)-(dist/beta))
            summ[j,i] += bf[pos]
        endif
    end
    
    if(eucl_dist==1)
        parallel_do(size(bf), fcalcbfeucl)
    else
        parallel_do(size(bf), fcalcbf)
    endif
    
    if(normalize)
        function [] = __kernel__ fnormbl(pos:ivec3)
            bf[pos] = bf[pos]/summ[pos[0], pos[1]]
        end
        parallel_do(size(bf), fnormbl)
    endif
end

% Function: apply_bilateral_filter
%
% Applies the bilateral filter to an image
%
% Parameters:
% bf - bilateral filter coefficients
% n_width - width of the filter window
% n_height - height of the filter window
%
% :function result:cube = apply_bilateral_filter(image:cube, bf:cube, n_width:int, n_height:int)
function result:cube = apply_bilateral_filter(image:cube, bf:cube, n_width:int, n_height:int)
    height:int = size(image,0)
    width:int  = size(image,1)
    ny2 = floor((n_height-1)/2)
    nx2 = floor((n_width -1)/2)
    
    result = zeros(height, width, 3)
    summ = zeros(height, width)
    
    function [] = __kernel__ fsum(pos:ivec3)
        xoff = mod(pos[2], n_width)-nx2
        yoff = floor(pos[2]/n_width)-ny2
        if(pos[0]+yoff < 0 || pos[0]+yoff >= height || pos[1]+xoff < 0 || pos[1]+xoff >= width)
            return 
        endif
        result[pos[0], pos[1], 0] += image[pos[0]+yoff, pos[1]+xoff, 0]*bf[pos]
        result[pos[0], pos[1], 1] += image[pos[0]+yoff, pos[1]+xoff, 1]*bf[pos]
        result[pos[0], pos[1], 2] += image[pos[0]+yoff, pos[1]+xoff, 2]*bf[pos]
        summ[pos[0], pos[1]] += bf[pos]
    end
    parallel_do([height, width, n_height*n_width], fsum)
    
    function [] = __kernel__ fnorm(pos:ivec3)
        x = result[pos] / summ[pos[0], pos[1]]
        result[pos] = x
    end
    parallel_do(size(result), fnorm)    
end

function [] = main()
    img = imread("lena_big.tif")
    nx=7;ny=7
    alpha=2*5^2; beta = 2*3^2,
    labimg = rgb2lab(img)
    
    s = 0
    its=25
    t=sprintf("Size of the image: %dx%d, size of the neighbourhood: %dx%d", size(img,1), size(img,0), nx,ny)
    print(t)
    for i = 1..its
        tic()
        bf = compute_bilateral_filter(labimg, nx,ny, alpha, beta, 0, 0)
        s+=toc("")
    end
    t=sprintf("Took on average %d milliseconds for computing the bilateral coefficients", s/its)
    print(t)
    
    s = 0
    for i = 1..its
        tic()
        %compute bf on the lab image, but filter the RGB one!
        filtered = apply_bilateral_filter(img, bf, nx, ny)
        s+=toc("")
    end
    t=sprintf("Took on average %d milliseconds for applying the bilateral coefficients", s/its)
    print(t)
    imshow(img)
    imshow(filtered)
end
