default: fmt-layouts

fmt-layouts:
    for file in `git ls-files 'layouts/*.html'`; do \
        tmp=$(mktemp); \
        gotmplfmt < "$file" > "$tmp" && mv "$tmp" "$file"; \
    done
