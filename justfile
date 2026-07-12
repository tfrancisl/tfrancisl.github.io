exclude-nix-files := ('.tack/default.nix')

fmt-layouts:
    for file in `git ls-files 'layouts/*.html'`; do \
        tmp=$(mktemp); \
        gotmplfmt < "$file" > "$tmp" && mv "$tmp" "$file"; \
    done
format:
    treefmt
lint:
    deadnix --exclude {{exclude-nix-files}} --fail .
    statix check -i {{exclude-nix-files}} .
