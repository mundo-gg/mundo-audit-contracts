import fs from 'fs'

export const getRemappings = () => {
    return fs
      .readFileSync("remappings.txt", "utf8")
      .split("\n")
      .filter(Boolean) // remove empty lines
      .map((line) => line.trim().split("="));
  }

  export default getRemappings