package com.github.oehme.sobula

import com.google.common.base.Charsets
import com.google.common.io.Files
import nebula.plugin.contacts.BaseContactsPlugin
import nebula.plugin.contacts.ContactsExtension
import nebula.plugin.publishing.NebulaJavadocJarPlugin
import nebula.plugin.publishing.NebulaSourceJarPlugin
import nebula.plugin.publishing.maven.NebulaMavenPublishingPlugin
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.publish.PublishingExtension
import org.gradle.api.publish.maven.MavenPublication
import org.w3c.dom.Document
import org.w3c.dom.Element
import org.w3c.dom.Node
import org.w3c.dom.NodeList

class ReleasePlugin implements Plugin<Project> {
	public static val RELEASE_TASK_NAME = "release"

	override apply(Project project) {
		val it = project
		plugins.<BaseContactsPlugin>apply(BaseContactsPlugin)
		plugins.<NebulaJavadocJarPlugin>apply(NebulaJavadocJarPlugin)
		plugins.<NebulaSourceJarPlugin>apply(NebulaSourceJarPlugin)
		plugins.<NebulaMavenPublishingPlugin>apply(NebulaMavenPublishingPlugin)

		tasks.create(RELEASE_TASK_NAME) [
			description = "Releases archives to public repositories"
			group = "publishing"
		]

		if (project.hasProperty("releaseVersion")) {
			version = project.property("releaseVersion")
			status = "release"
		}

		val publish = extensions.getByType(PublishingExtension)
		publish.publications.withType(MavenPublication) [
			project.afterEvaluate [ p |
				pom.withXml [
					val root = asElement
					val extension builder = new DocumentBuilder(root.ownerDocument)
					val gitHubUser = project.gitHubUser
					if (gitHubUser != null) {
						val gitHubProject = project.rootProject.name
						val connection = '''scm:git@github.com:«gitHubUser»/«gitHubProject».git'''
						val url = '''https://github.com/«gitHubUser»/«gitHubProject»'''
						root => [
							simpleElement("url", url)
							element("scm") [
								simpleElement("connection", connection)
								simpleElement("developerConnection", connection)
								simpleElement("url", url)
							]
							element("issueManagement") [
								simpleElement("system", "GitHub Issues")
								simpleElement("url", '''«url»/issues''')
							]
						]
					}
					root => [
						if (getElementsByTagName("license").length == 0) {
							val license = project.license
							if (license != null) {
								element("licenses") [
									element("license") [
										simpleElement("name", license.longName)
										simpleElement("url", license.url)
										simpleElement("distribution", "repo")
									]
								]
							}
						}
					]
					val compileConfig = project.configurations.getAt("compile")
					root.getElementsByTagName("dependency").forEach [
						if (it instanceof Element) {
							val scope = getElementsByTagName("scope").item(0)
							val artifactId = getElementsByTagName("artifactId").item(0)
							val artifactInCompileConfig = compileConfig.allDependencies.findFirst [
								name == artifactId.textContent
							]
							if (scope.textContent == "runtime" && artifactInCompileConfig != null) {
								scope.textContent = "compile"
							}
						}
					]
				]
			]
		]
	}
	
	private def forEach(NodeList nodes, (Node) => void procedure) {
		for(var i = 0; i < nodes.length; i++) {
			procedure.apply(nodes.item(i))
		}
	}

	static def getGitHubUser(Project project) {
		project.extensions.getByType(ContactsExtension).people.values.findFirst[roles.contains("owner")]?.github
	}

	static def getLicense(Project project) {
		val licenseFile = project.rootProject.file("LICENSE")
		if (licenseFile.exists) {
			val content = Files.toString(licenseFile, Charsets.UTF_8)
			return License.values.findFirst[matches(content)]
		}
		return null
	}

	@FinalFieldsConstructor
	private static class DocumentBuilder {
		val Document document

		def element(Node parent, String tag, (Element)=>void init) {
			val element = document.createElement(tag);
			init.apply(element)
			parent.appendChild(element)
			element
		}

		def simpleElement(Node parent, String tag, String text) {
			parent.element(tag)[textContent = text]
		}
	}
}
