// MathJax 3 配置 (Material for MkDocs 官方配方)
// 加载顺序: 本文件先于 tex-mml-chtml.js (见 mkdocs.yml extra_javascript)
window.MathJax = {
  tex: {
    inlineMath: [["\\(", "\\)"]],
    displayMath: [["\\[", "\\]"]],
    processEscapes: true,
    processEnvironments: true
  },
  options: {
    ignoreHtmlClass: ".*|",
    processHtmlClass: "arithmatex"
  }
};
