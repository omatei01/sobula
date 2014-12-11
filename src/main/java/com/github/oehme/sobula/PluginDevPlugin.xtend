package com.github.oehme.sobula

import com.jfrog.bintray.gradle.BintrayExtension
import java.io.File
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.plugins.JavaPluginConvention
import org.gradle.devel.plugins.JavaGradlePluginPlugin

class PluginDevPlugin implements Plugin<Project> {

	override apply(Project project) {
		project.plugins.<JavaGradlePluginPlugin>apply(JavaGradlePluginPlugin)
		project.plugins.<BintrayReleasePlugin>apply(BintrayReleasePlugin)
		project.afterEvaluate [
			extensions.getByType(BintrayExtension) => [
				pkg => [
					version => [
						if (!attributes.containsKey("gradle-plugin")) {
							val possiblePluginProjects = project.subprojects + #[project]
							val gradlePlugins = possiblePluginProjects.map[gradlePluginDefinitions].flatten.toSet
							if (!gradlePlugins.isEmpty) {
								attributes.put("gradle-plugin", gradlePlugins)
							}
						}
					]
				]
			]
		]
	}

	private def getGradlePluginDefinitions(Project subProject) {
		val java = subProject.convention.findPlugin(JavaPluginConvention)
		if (java != null) {
			val mainSourceSet = java.sourceSets.getAt("main")
			if (mainSourceSet != null) {
				val resourceFolders = mainSourceSet.resources.srcDirs
				val gradlePluginsDir = resourceFolders.map[new File(it, 'META-INF/gradle-plugins')].findFirst[exists]
				if (gradlePluginsDir != null) {
					return gradlePluginsDir.listFiles.map [
						val pluginName = name.replace(".properties", "")
						'''«pluginName»:«subProject.group»:«subProject.name»'''
					].toSet
				}
			}
		}
		return #{}
	}
}
