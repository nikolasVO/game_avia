using System;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.SceneManagement;

// Technical fixture only. No gameplay or TRELLIS provenance is implied.
public static class AviaProof
{
    [Serializable] private sealed class Evidence
    {
        public bool passed;
        public string editor, sourceKind, buildResult, error;
        public int lod0Triangles, materials;
        public bool lodGroup, boxCollider, bottomPivot;
    }

    public static void Build()
    {
        var evidence = new Evidence { editor = Application.unityVersion,
            sourceKind = "procedural_test_fixture_not_TRELLIS" };
        try
        {
            if (Application.unityVersion != "6000.3.28f1")
                throw new Exception("Editor version mismatch");
            Directory.CreateDirectory("Assets/Proof");
            var renderer = ScriptableObject.CreateInstance<UniversalRendererData>();
            AssetDatabase.CreateAsset(renderer, "Assets/Proof/Renderer.asset");
            var pipeline = UniversalRenderPipelineAsset.Create(renderer);
            AssetDatabase.CreateAsset(pipeline, "Assets/Proof/Pipeline.asset");
            GraphicsSettings.defaultRenderPipeline = pipeline;
            QualitySettings.renderPipeline = pipeline;
            string source = Path.GetFullPath("../../assets/catalog/blender-fixture/optimized.glb");
            File.Copy(source, "Assets/Proof/fixture.glb", false);
            AssetDatabase.ImportAsset("Assets/Proof/fixture.glb", ImportAssetOptions.ForceSynchronousImport);
            var imported = AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Proof/fixture.glb");
            if (imported == null) throw new Exception("glTFast did not import the real GLB");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            var root = (GameObject)PrefabUtility.InstantiatePrefab(imported);
            root.name = "ProceduralFixture";
            foreach (var r in root.GetComponentsInChildren<Renderer>())
                if (r.name == "COLLISION_BOX") r.enabled = false;
            var levels = Enumerable.Range(0, 3).Select(i => root.GetComponentsInChildren<MeshRenderer>()
                .Where(r => r.name == "LOD" + i).Cast<Renderer>().ToArray()).ToArray();
            if (levels.Any(l => l.Length == 0)) throw new Exception("Missing real GLB LOD mesh");
            var group = root.AddComponent<LODGroup>();
            group.SetLODs(new[] { new LOD(0.6f, levels[0]), new LOD(0.3f, levels[1]), new LOD(0.05f, levels[2]) });
            group.RecalculateBounds();
            var bounds = levels[0][0].bounds;
            foreach (var r in levels[0].Skip(1)) bounds.Encapsulate(r.bounds);
            evidence.lod0Triangles = levels[0].Sum(r => r.GetComponent<MeshFilter>().sharedMesh.triangles.Length / 3);
            evidence.materials = levels[0].SelectMany(r => r.sharedMaterials).Distinct().Count();
            evidence.bottomPivot = Mathf.Abs(bounds.min.y) < 0.01f && Mathf.Abs(bounds.center.x) < 0.01f
                && Mathf.Abs(bounds.center.z) < 0.01f;
            if (evidence.lod0Triangles != 188 || evidence.materials != 1 || !evidence.bottomPivot
                || Vector3.Distance(bounds.size, Vector3.one) > 0.02f)
                throw new Exception("Imported geometry differs from the measured fixture");
            var collider = root.AddComponent<BoxCollider>();
            collider.center = root.transform.InverseTransformPoint(bounds.center);
            collider.size = bounds.size;
            evidence.lodGroup = group.GetLODs().Length == 3;
            evidence.boxCollider = collider.enabled;
            PrefabUtility.SaveAsPrefabAsset(root, "Assets/Proof/Fixture.prefab");
            var camera = new GameObject("Camera").AddComponent<Camera>();
            camera.tag = "MainCamera";
            camera.transform.position = new Vector3(2, 1.8f, -3);
            camera.transform.LookAt(bounds.center);
            camera.backgroundColor = new Color(0.12f, 0.15f, 0.2f);
            camera.clearFlags = CameraClearFlags.SolidColor;
            var light = new GameObject("Light").AddComponent<Light>();
            light.type = LightType.Directional;
            light.transform.rotation = Quaternion.Euler(40, -30, 0);
            RenderSettings.ambientLight = Color.gray;
            EditorSceneManager.SaveScene(scene, "Assets/Proof/Proof.unity");
            AssetDatabase.SaveAssets();
            var output = Environment.GetEnvironmentVariable("GAME_AVIA_UNITY_BUILD_DIR");
            if (String.IsNullOrEmpty(output)) throw new Exception("Missing private build output directory");
            PlayerSettings.productName = "AviaTechnicalProof";
            var result = BuildPipeline.BuildPlayer(new BuildPlayerOptions {
                scenes = new[] { "Assets/Proof/Proof.unity" },
                locationPathName = Path.Combine(output, "AviaTechnicalProof.app"),
                target = BuildTarget.StandaloneOSX, options = BuildOptions.Development });
            evidence.buildResult = result.summary.result.ToString();
            if (result.summary.result != BuildResult.Succeeded) throw new Exception("Build did not succeed");
            evidence.passed = true;
        }
        catch (Exception e) { evidence.error = e.Message; Debug.LogException(e); }
        File.WriteAllText(Environment.GetEnvironmentVariable("GAME_AVIA_UNITY_REPORT"), JsonUtility.ToJson(evidence, true));
        EditorApplication.Exit(evidence.passed ? 0 : 1);
    }
}
