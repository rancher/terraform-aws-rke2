package fixtures

import (
	"errors"
	"strings"
	"testing"
)

func GetCombinations (t *testing.T) (map[string]map[string]string, error){
	data, keys, err := getData()
	if err != nil {
		return nil, err
	}
	m := getMaxes(data,keys)
	indexes := getIndexes(m, keys)
	c, err := getCombos(data, indexes, keys)
	if err != nil {
		return nil, err
	}

	releases, err := GetReleases()
	if err != nil {
		return nil, err
	}
  latest := releases[0]
  stable := releases[1]
  old    := releases[2]

  // this enables us to refer to the combinations dynamically
  cc := make(map[string]map[string]string)
  for k,v := range c {
    k = strings.Replace(k, latest, "latest", 1) // replace the latest release version with the word 'latest'
    k = strings.Replace(k, stable, "stable", 1) // replace the next release version with the word 'stable'
    k = strings.Replace(k, old,    "old",    1) // replace the next release version with the word 'old'

    cc[k] = v
  }

	return cc, nil
}

func getCombos(data map[string][]string, indexes []map[string]int, keys []string) (map[string]map[string]string, error) {
	var combos []map[string]string

	for i := range indexes {
		index := indexes[i]
		combo := make(map[string]string)
		for j := range keys {
			key := keys[j]
			indexForKey := index[key]
			combo[key] = data[key][indexForKey]
		}
		combos = append(combos, combo)
	}

	comboNames := make([]string, len(combos))

	for i := range combos {
		combo := combos[i]

		var comboValues []string
		for j := range keys {
			key := keys[j]
			v := combo[key]
			comboValues = append(comboValues, v)
		}
		comboName := strings.Join(comboValues, "-")
		comboNames[i] = comboName
	}

	combosMap := make(map[string]map[string]string)
	for i := range combos {
		comboName := comboNames[i]
		combo := combos[i]
		combosMap[comboName] = combo
	}
	return combosMap, nil
}

func getData() (map[string][]string, []string, error){
  fixtures         := []string{"one", "ha", "splitrole"} // these must match the example directory names
  installTypes     := []string{"rpm", "tar"}
  cni              := []string{"canal", "calico", "cilium"}
  operatingSystems := []string{
    "sles-15",
    "sle-micro-55",
    "rhel-8-cis",
    "ubuntu-20",
    "ubuntu-22",
    "rocky-8",
    "liberty-7",
    "rhel-9",
    "rhel-8",
  }
  ipFamilies         := []string{"ipv4", "ipv6", "dualstack"}
  ingressControllers := []string{"nginx","traefik"}

  releases, err := GetReleases()
	if err != nil {
		return nil, nil, err
	}
  if len(releases) == 0 {
    err := errors.New("no releases found")
    return nil, nil, err
  }

  data := map[string][]string{
    "operatingSystem": operatingSystems,
    "cni": cni,
		"release": releases,
    "fixture": fixtures,
    "installType": installTypes,
    "ipFamily": ipFamilies,
    "ingressController": ingressControllers,
  }
	keys := []string{
		"operatingSystem",
		"cni",
		"release",
		"fixture",
		"installType",
		"ipFamily",
		"ingressController",
	}
  return data, keys , nil
}

func getMaxes(d map[string][]string, k []string) map[string]int {
	result := make(map[string]int)
	for i := range k {
		key := k[i]
		result[key] = len(d[key]) - 1
	}
	return result
}

func getIndexes(maxValues map[string]int, k []string) []map[string]int {
  var results []map[string]int // slice of maps to hold the result
  current := make(map[string]int) // a map to mutate

  for i := range k {
		current[k[i]] = 0 // fill in the initial values of current
	}
  lastKey := k[len(k)-1]
	for (current[lastKey] < maxValues[lastKey]) { // until the last value of current matches the last max value

    // create copy of current
		c := make(map[string]int)
    for key, value := range current {
      c[key] = value
    }
    results = append(results, c) // store the copy to the results slice

		// keep processing current
    current[k[0]]++ // increment the value of the first key, then rearrange if necessary

    for i := range k { // loop through the keys in order
      key := k[i]
      if current[key] > maxValues[key] { // if the value of the current key is greater than the max value for that key
        current[key] = 0 // reset the value of the current key to 0
        current[k[i+1]]++ // increment the value of the next key
      }
    }
	}
	return results
}

func GetReleases() ([]string, error){
  latest, stable, lts, err := GetRke2Releases()
  if err != nil {
    return nil, err
  }
  return []string{
    latest,
    stable,
    lts,
  }, nil
}
