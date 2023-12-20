# Dynamic Maven Properties Handlging with Git Security 

Originally crafted to address [a question posed by Dimitris on Stack Overflow](https://stackoverflow.com/questions/76389470/pass-database-information-from-properties-file-in-pom-in-spring-boot).

The most efficient method to safeguard sensitive data in your files when pushing to a repository is by leveraging the default git filtering mechanism. Using sed, it becomes possible to identify a specific string, such as a plain-text password in our files, and replace it with an obfuscated value. This process, performed during the `staging` phase, is known as the `clean filter`. Conversely, the reverse operation, where files are searched for obfuscated values and replaced back with the original content during the `checkout` phase, is referred to as the `smudge filter`.

While it's straightforward to apply this approach to various file types like .java, .js, .c, .cpp, .txt, etc., dealing with .xml files, such as the `pom.xml` file, poses a slight challenge.

In instances where a plugin necessitates a value to be specified and presented in the POM file, as in your scenario, maintaining the cleanliness and manageability of the POM is crucial. To achieve this, it is advisable to extract such values from their original locations to an upper level and define them under the properties section. However, this alone does not prevent sensitive data from being inadvertently pushed to the repository.

Nevertheless, this approach allows us to attain our objective through an alternative method, employing a minor workaround. By storing our static values under properties, we can extract them from the POM file and store them in a regular .properties file. Subsequently, we can reintegrate these values back into our POM using the [Properties Maven Plugin](https://www.mojohaus.org/properties-maven-plugin/).

To implement this solution, it is necessary to add the following plugin configuration to our POM under the `build/plugins` section.

```
<plugin>
    <groupId>org.codehaus.mojo</groupId>
    <artifactId>properties-maven-plugin</artifactId>
    <version>1.2.1</version>
    <executions>
        <execution>
            <phase>initialize</phase>
            <goals>
                <goal>read-project-properties</goal>
            </goals>
            <configuration>
                <override>false</override>
                <useDefaultValues>true</useDefaultValues>
                <files>
                    <file>etc/config/dev.properties</file>
                </files>
            </configuration>
        </execution>
    </executions>
</plugin> 
```
Assuming the file address used in the example, it is only necessary to store our static values in a file named `dev.properties` located under `${basedir}/etc/config/`. Therefore, moving forward, during the initialization phase, the Properties Maven Plugin will read the saved (name, value) property pairs and adjust our `pom.xml` as if these values were directly defined in the POM itself.

With this setup, it becomes feasible to apply the git filtering mechanism over the `dev.properties file`. Additionally, for enhanced flexibility in the long run, employing [a script similar to the one suggested by TomerFi](https://gist.github.com/TomerFi/0911f573ea0474b9ab74bcfcef0f2a49) is recommended. This script can be saved in a `.sh` file under a `./scripts` folder.
```
declare -A mapArr

mapArr["prodPassword"]="obfuscatedProductionPassword"
mapArr["devPassword"]="obfuscatedDevelopmentPassword"

# mac users: use gsed instead of sed
sedcmd="sed"
if [[ "$1" == "clean" ]]; then
  for key in ${!mapArr[@]}; do
    sedcmd+=" -e \"s/${key}/${mapArr[${key}]}/g\""
  done  
elif [[ "$1" == "smudge" ]]; then
  for key in ${!mapArr[@]}; do
    sedcmd+=" -e \"s/${mapArr[${key}]}/${key}/g\""
  done  
else  
  echo "use smudge/clean as the first argument"
  exit 1
fi

eval $sedcmd
```
**In a real world example you would and should include this script file in your `.gitignore` so it won't be publicly available, otherwise what's the point of all this?**

For the script to be invoked during the staging and checkout phases, as mentioned earlier, the local git config file should be updated with the following commands:
```
git config filter.cleanPass.smudge "./scripts/git-smudge-clean-filter.sh smudge"
git config filter.cleanPass.clean "./scripts/git-smudge-clean-filter.sh clean" 
```
Later, the `.gitattribute`s file should be included in the repository's root. This instructs git to apply the added clean and smudge filters over the specified file types.
```
*.properties text eol=lf filter=cleanPass
```
Hence, the public exposure of sensitive data is avoided.

Furthermore, this solution is easily scalable for setting up a plugin with different static values for various environments/platforms. In such scenarios, defining different profiles in the `pom.xml` becomes essential. For each profile, the Properties Maven Plugin should be defined and configured separately and in accordance with the profile's purpose. This diverges from the previously demonstrated definition that occurred under the global build/plugins section of the `pom.xml`. By adopting this approach, each profile can load its set of relevant properties. In simpler terms, for our development-targeted builds, we can load the pertinent database password saved in the `dev.properties` file. Conversely, when targeting a build for production, the password saved in `prod.properties` would be loaded.

A rough overview of the final structure looks like this:
```
root
   |
   |- .git/
   |- etc/config
   |			|- dev.properties
   |			|- prod.properties
   |- scripts/
   |		|- git-smudge-clean-filter.sh
   |- pom.xml
   |- .gitattribute
```
and the `pom.xml` roughly would look like this:
```
<project>
    <profiles>
        <profile>
            <id>dev-env</id>
            <build>
                <plugins>
                    <plugin>
                        <groupId>org.codehaus.mojo</groupId>
                        <artifactId>properties-maven-plugin</artifactId>
                        <version>1.2.1</version>
                        <executions>
                            <execution>
                                <phase>initialize</phase>
                                <goals>
                                    <goal>read-project-properties</goal>
                                </goals>
                                <configuration>
                                    <override>false</override>
                                    <useDefaultValues>true</useDefaultValues>
                                    <files>
                                        <file>etc/config/dev.properties</file>
                                    </files>
                                </configuration>
                            </execution>
                        </executions>
                    </plugin> 
                </plugins>
            </build>
        </profile>
        <profile>
            <id>prod-env</id>
            <build>
                <plugins>
                    <plugin>
                        <groupId>org.codehaus.mojo</groupId>
                        <artifactId>properties-maven-plugin</artifactId>
                        <version>1.2.1</version>
                        <executions>
                            <execution>
                                <phase>initialize</phase>
                                <goals>
                                    <goal>read-project-properties</goal>
                                </goals>
                                <configuration>
                                    <override>false</override>
                                    <useDefaultValues>true</useDefaultValues>
                                    <files>
                                        <file>etc/config/prod.properties</file>
                                    </files>
                                </configuration>
                            </execution>
                        </executions>
                    </plugin> 
                </plugins>
            </build>
        </profile>
    </profiles>
    <build>
        <plugins>
            <plugin>
                <groupId>org.flywaydb</groupId>
                <artifactId>flyway-maven-plugin</artifactId>
                <configuration>
                    <url>${db.url}</url>
                    <user>${db.username}</user>
                    <password>${db.password}</password>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```
finally, `dev.properties` should look like this:
```
db.url=localhost:8088
db.username=root
db.password=devPassword
```
while the `prod.propertie`s looks like this:
```
db.url=https://secure-server.i0:3534
db.username=dbManager
db.password=prodPassword
```


In all of this, we've effectively moved away from working with statically defined properties in our `pom.xml`! Now, we have a fully dynamic approach while maintaining our security measures upon pushing to a repository.
