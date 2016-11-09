import "Quasar.Runtime.dll"
import "colortransform.q"
import "Quasar.UI.dll"
import "immorphology.q"

import "inttypes.q"
import "system.q"

%%%%%%%%%% Point class %%%%%%%%%
type point: mutable class
    x:int
    y:int
end

function y = point (px : int, py : int )
 y = point(x:=px,y:=py) 
end

function y = point()
 y = point(x:=-1,y:=-1) 
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%% Point list class %%%%%%%
type node:mutable class
    p:point
    next:^point
end

function y=node(p:point,n:^point)
    y=node(p:=point(p.x,p.y),next:=n)
end

type point_list: mutable class
    list_size:int
    first_node:node
end

function y = point_list()
    y = point_list(list_size:=0,first_node:=node(p:=point(),next:=nullptr))
end

function y = addPoint(self:point_list,p:point) 
    if(self.list_size==0)
        self.first_node=node(p:=point(p.x,p.y),next:=nullptr)
        self.list_size=1
    else
        seek:node=self.first_node
        while (seek.next != nullptr)
            seek=seek.next
        end
        seek.next=p
        self.list_size=self.list_size+1;
    endif    
    y=self
end

function y=isEmpty(self:point_list)
    if(self.list_size>0)
        y=false
    else
        y=true
    endif
end            
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%% Blob class %%%%%%%%%%
type blob: mutable class
    label:int
    pos:point
    width:int
    height:int
    points:point_list
end

function y = blob()
 y = blob(label:=-1,width:=0,height:=0,pos=point()) 
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function list:point_list =  getConectedElements(data:mat'mirror,y:int,x:int)
    list:point_list=point_list();
    for r=0..2
        for c=0..2
            if(data[y+r,x+c]==1)
                p:point=point(x:=x+c,y:=y+r) 
                list.addPoint(p)
            endif     
        end
    end        
end



function[]= dfs(m:mat,y:int,x:int,w:int,h:int,label:mat,current_label:int) 
  % direction vectors
  dx = [1, 0, -1, 0];
  dy = [0, 1, 0, -1];
  
  % is not out of bounds
  if(x>=0 && y>=0 && x<h && y<w)
    if(label[x,y]==0 && m[x,y]!=0)  % is not labeled or not marked with 1 in m
       % mark the current cell
       label[x,y] = current_label;

       % recursively mark the neighbors
       for direction = 0..3
         dfs(m,y+dy[direction],x+dx[direction],w,h,label,current_label);
       end
    endif  
  endif
  
end



% Return a vector with blobs detected
% img: input matrix, 0-background, 1-foreground
% con: conectivity: 2 or 4
function label:mat = findBlobs(m:mat)

    % matrix dimensions
    [row_count,col_count]=size(m)

    % the labels, 0 means unlabeled
    label = zeros(row_count,col_count)

    component = 0;
    for i=0..row_count-1 
       for j=0..col_count-1 
            if (label[i,j]==0 && m[i,j]!=0)
                 component=component+1
                 dfs(m,j,i,col_count,row_count,label,component);
            endif
       end
    end             
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Blob finder                                                          %
% Authpr: Gonzalo Luzardo                                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [] = main()
    im = imread("lena_big.tif")
    im = rgb2gray(im)
    im = (im>200).*im
    mask=[[0,1,0],[1,1,1],[0,1,1]]
    for k=0..3
        im = imerode(im,mask,[1,1])
    end
    for k=0..3
        im = imdilate(im,mask,[1,1])
    end
    
   % im=[[1,1,0,1],[0,1,0,0],[0,0,0,0],[1,1,1,1]]
    
%    b = findBlobs(im)
    
    imshow(im)
end
