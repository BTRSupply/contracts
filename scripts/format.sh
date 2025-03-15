#!/bin/bash

# Load variables from sol.yml
eval "$(yq -o=shell ../assets/desc/sol.yml)"

# Process only files defined in sol.yml
yq -I0 -r '.evm.src.facets.abstract | to_entries[].key' ../assets/desc/sol.yml | while read -r file; do
  target="../evm/src/facets/abstract/$file"
  [ -f "$target" ] || continue
  
  # Extract file-specific metadata
  title=$(yq -r ".evm.src.facets.abstract.\"$file\".title" ../assets/desc/sol.yml)
  short_desc=$(yq -r ".evm.src.facets.abstract.\"$file\".short_desc" ../assets/desc/sol.yml)
  desc=$(yq -r ".evm.src.facets.abstract.\"$file\".desc" ../assets/desc/sol.yml)
  dev_comment=$(yq -r ".evm.src.facets.abstract.\"$file\".dev_comment" ../assets/desc/sol.yml)

  # Clean existing header - stop at first contract/struct/library/import or ///
  cleaned=$(sed '/^\(contract\|struct\|library\|\/\/\/\|import\)/,$!d' "$target")
  
  # Generate dynamic header
  header=$(sed -e "s/{{ title }}/$title/g" \
              -e "s/{{ short_desc }}/$short_desc/g" \
              -e "s/{{ desc }}/$desc/g" \
              -e "s/{{ dev_comment }}/$dev_comment/g" \
              -e "s/{{ licence }}/$defaults.licence/g" \
              -e "s/{{ author }}/$defaults.author/g" \
              -e "s/{{ sol_version }}/$defaults.sol_version/g" \
              ../assets/headers/sol.txt)
  
  # Inject generated header
  echo "$header"$'\n'"$cleaned" > "$target"
  echo "Processed: $target"
done
