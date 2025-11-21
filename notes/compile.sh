# ./fix_toc.sh
# ./rm_dup.sh
latexmk -pdf vulkan_guide.tex
makeglossaries vulkan_guide
latexmk -pdf vulkan_guide.tex
# latexmk -c
