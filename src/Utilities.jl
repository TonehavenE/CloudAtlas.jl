function myreaddlm(filename; cc='#')
    X = readdlm(filename, comments=true, comment_char=cc)
    if size(X,2) == 1
        X = X[:,1]
    end
    X
end

function halfbox_symmetries() 
   sx = Symmetry(-1,1,1,0,0)
   sy = Symmetry(1,-1,1,0,0)
   sz = Symmetry(1,1,-1,0,0)
   tx = Symmetry(1,1,1,0.5,0)
   tz = Symmetry(1,1,1,0,0.5)
   sx, sy, sz, tx, tz
end

