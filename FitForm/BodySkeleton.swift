//
//  BodeySkeleton.swift
//  FitForm
//
//  Created by Anish Aggarwal on 2022-08-19.
//

import ARKit
import Foundation
import RealityKit

class BodySkeleton: Entity {
    var joints: [String: Entity] = [:]
    var bones: [String: Entity] = [:]
    var jointsFormatted: [String: [Float]] = [:]

    required init(for bodyAnchor: ARBodyAnchor) {
        super.init()
        construct.initialize()
        controller.initialize(workouts: [])

        for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
            var jointRadius: Float = 0.05
            var jointColor: UIColor = .green

            switch jointName {
            case "left_shoulder_1_joint":
                jointRadius *= 0.5
                jointColor = .red
            case "neck_1_joint", "neck_2_joint", "neck_3_joint", "neck_4_joint", "heck_joint", "right_shoulder_1_joint":
                jointRadius *= 0.5
            case "jaw_joint", "chin_joint", "left_eye_joint", "left_eyeLowerLid_joint", "left_eyeUpperLid_joint",
                 "left_eyeball_joint", "nose_joint", "right_eye_joint", "right_eyeLowerLid_joint", "right_eyeUpperLid_joint", "right_eyeball_joint":
                jointRadius *= 0
                jointColor = .yellow
            case _ where jointName.hasPrefix("spine_"):
                jointRadius *= 0.75
            case "left_hand_joint", "right_hand_joint":
                jointRadius *= 1
                jointColor = .green
            case _ where jointName.hasPrefix("left_hand") || jointName.hasPrefix("right_hand"):
                jointRadius *= 0.25
                jointColor = .yellow
            case "left_arm_joint":
                jointRadius = 0.05
                jointColor = .blue
            case "left_forearm_joint":
                jointRadius = 0.05
                jointColor = .black
            default:
                jointRadius = 0.05
                jointColor = .green
            }

            let jointEntity = createJoint(radius: jointRadius, color: jointColor)
            joints[jointName] = jointEntity
            addChild(jointEntity)
        }

        for bone in Bones.allCases {
            guard let skeletonBone = createSkeletonBone(bone: bone, bodyAnchor: bodyAnchor)
            else { continue }

            let boneEntity = createBoneEntity(for: skeletonBone)
            bones[bone.name] = boneEntity
            addChild(boneEntity)
        }
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    func update(with bodyAnchor: ARBodyAnchor) {
        let rootPosition = simd_make_float3(bodyAnchor.transform.columns.3)

        for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
            if let jointEntity = joints[jointName],
               let jointEntityTransform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: jointName))
            {
                let jointEntityOffsetFromRoot = simd_make_float3(jointEntityTransform.columns.3)
                jointEntity.position = jointEntityOffsetFromRoot + rootPosition
                jointEntity.orientation = Transform(matrix: jointEntityTransform).rotation
                jointsFormatted[jointName] = [jointEntity.position.x, jointEntity.position.y, jointEntity.position.z]
            }
        }
        guard let encoded = try? JSONEncoder().encode(jointsFormatted) else {
            print("Failed to encode login info")
            return
        }

        construct.sendUDP(encoded)
        controller.update()

        for bone in Bones.allCases {
            let boneName = bone.name
            guard let entity = bones[boneName],
                  let skeletonBone = createSkeletonBone(bone: bone, bodyAnchor: bodyAnchor)
            else { continue }

            entity.position = skeletonBone.centerPosition
            entity.look(at: skeletonBone.toJoint.position, from: skeletonBone.centerPosition, relativeTo: nil)
        }
    }

    private func createJoint(radius: Float, color: UIColor = .white) -> Entity {
        let mesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
        let entity = ModelEntity(mesh: mesh, materials: [material])

        return entity
    }

    private func createSkeletonBone(bone: Bones, bodyAnchor: ARBodyAnchor) -> SkeletonBone? {
        guard let fromJointEntityTransform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: bone.jointToName)),
              let toJointEntityTransform = bodyAnchor.skeleton.modelTransform(for: ARSkeleton.JointName(rawValue: bone.jointToName))
        else { return nil }

        let rootPosition = simd_make_float3(bodyAnchor.transform.columns.3)

        let jointFromEntityOffsetFromRoot = simd_make_float3(fromJointEntityTransform.columns.3)

        let jointFromEntityPosition = jointFromEntityOffsetFromRoot + rootPosition

        let jointToEntityOffsetFromRoot = simd_make_float3(toJointEntityTransform.columns.3)

        let jointToEntityPosition = jointToEntityOffsetFromRoot + rootPosition

        let fromJoint = SkeletonJoint(name: bone.jointFromName, position: jointFromEntityPosition)
        let toJoint = SkeletonJoint(name: bone.jointToName, position: jointToEntityPosition)
        return SkeletonBone(fromJoint: fromJoint, toJoint: toJoint)
    }

    private func createBoneEntity(for skeletonBone: SkeletonBone, diameter: Float = 0.04, color: UIColor = .white) -> Entity {
        let mesh = MeshResource.generateBox(size: [diameter, diameter, skeletonBone.length], cornerRadius: diameter / 2)
        let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [material])

        return entity
    }
}
